"""Plant action acceptance against the CURRENT package and restored/upgraded data."""
import hashlib, json, re, time
from datetime import date,timedelta
from pathlib import Path
from urllib.parse import quote,parse_qs,urlsplit
from http_support import HERE,RESULTS,sql,fetch,Forms,get_form,save,check,make_photo,jpeg_dimensions
today=date.fromisoformat(sql('SELECT CURRENT_DATE();'))
def day(offset):return (today+timedelta(days=offset)).isoformat()
S={}
history_query='SELECT versionId,HEX(scriptName),HEX(checksum),appliedAt FROM orchids.schemaversion ORDER BY versionId;'
history_before=sql(history_query)
taxon=int(sql('SELECT t.taxonId FROM orchids.taxon t JOIN orchids.genus g ON g.genusId=t.genusId WHERE t.isActive=1 AND g.isActive=1 AND t.isSystemManaged=0 ORDER BY t.taxonId LIMIT 1;'))
locations=[int(x) for x in sql('SELECT locationId FROM orchids.location WHERE isActive=1 ORDER BY locationId LIMIT 2;').splitlines()]
media=[int(x) for x in sql('SELECT growthMediumId FROM orchids.growthmedium WHERE isActive=1 ORDER BY growthMediumId LIMIT 2;').splitlines()]
assert len(locations)==2 and len(media)==2,'Two active locations and growth media required'

def parent():
    assert 'parent' in S,'Test parent setup did not complete'
    return S['parent']

def action(kind):return f'/Plants/Events/Add/{parent()}/{kind}'

def details_contain(marker):
    r=fetch(f'/Plants/Details/{parent()}')
    assert r['status']==200 and marker in r['body'],'Saved marker missing from rendered plant history'

def event_record(marker,code,expected_day):
    row=sql(f"SELECT e.plantEventId,t.typeCode,DATE(e.eventDateTime),e.isActive FROM orchids.plantevent e JOIN orchids.observationtype t ON t.Id=e.observationTypeId WHERE e.plantId={parent()} AND e.eventDetails LIKE '%{marker}%';").splitlines()
    assert len(row)==1,'Expected exactly one saved observation'
    values=row[0].split('\t')
    assert values[1:]==[code,expected_day,'1'],values[1:]
    details_contain(marker)
    return int(values[0])

def setup_parent():
    path=f'/Plants/Add/Create/{taxon}'
    form=get_form(path,field='Input.PlantName')
    name='CI basic actions parent 080ba9c'
    save(path,form,{'Input.PlantName':name,'Input.AcquisitionDate':day(-90),
                    'Input.AcquisitionSource':'CI synthetic specimen','Input.PlantNotes':'CI basic actions setup'})
    rows=sql(f"SELECT plantId,plantTag FROM orchids.plant WHERE plantName='{name}';").splitlines()
    assert len(rows)==1
    plant_id,tag=rows[0].split('\t');S.update(parent=int(plant_id),parent_tag=tag)
    path=action('LocationChange');form=get_form(path,field='LocationId')
    save(path,form,{'LocationId':str(locations[0]),'EventDate':day(-80),
                    'EventDetails':'CI initial placement','PlantLocationNotes':'CI initial location'})
    assert int(sql(f'SELECT locationId FROM orchids.vplantcurrentlocation WHERE plantId={parent()};'))==locations[0]
    return {'parent_id':parent(),'taxon_id':taxon,'acquired':day(-90),'initial_location':locations[0]}
check('Create dedicated test parent and initial placement',setup_parent)

def quick(action_name,code,marker,when):
    path=action('Observation');form=get_form(path,field='EventDetails')
    assert any(b.get('name')=='quickAction' and b.get('value')==action_name for b in form['submitters']), 'Quick-action button missing'
    before=sql(f'SELECT COUNT(*) FROM orchids.plantevent WHERE plantId={parent()};')
    response=fetch(path,data={**form['fields'],'quickAction':action_name})
    assert response['status']==200,'Quick action did not reopen the form'
    assert sql(f'SELECT COUNT(*) FROM orchids.plantevent WHERE plantId={parent()};')==before,'Quick-action selection saved an event prematurely'
    prepared=next(f for f in Forms(response['body']).forms if 'EventDetails' in f['fields'])
    assert prepared['fields']['QuickObservationTypeCode']==code
    return path,prepared

def feed(action_name,code,marker,when):
    path,form=quick(action_name,code,marker,when)
    default=form['fields']['EventDetails']
    assert default.strip(),'Feed action did not prefill notes'
    save(path,form,{'EventDate':day(when),'EventDetails':default+' — '+marker})
    event_id=event_record(marker,code,day(when))
    return {'event_id':event_id,'observation_type':code,'quick_selection_does_not_save':True,'history_verified':True}
check('Observation quick action: feed growth',lambda:feed('feedGrowth','OBS_FEED_GROWTH','CI growth feed',-30))
check('Observation quick action: feed bloom',lambda:feed('feedBloom','OBS_FEED_BLOOM','CI bloom feed',-29))

def note():
    path=action('Observation');form=get_form(path,field='EventDetails')
    save(path,form,{'EventDate':day(-28),'EventDetails':'CI standalone observation note'})
    event_id=event_record('CI standalone observation note','OBS_NOTE',day(-28))
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plantphoto WHERE plantEventId={event_id};'))==0
    return {'event_id':event_id,'type':'OBS_NOTE','photo_records':0,'history_verified':True}
check('Observation: standalone note',note)

make_photo(HERE/'action-photo.png')

def photo_note():
    path,form=quick('photo','OBS_PHOTO','CI photo and observation note',-27)
    assert 'UploadedFiles' in form['files'],'Photo quick action did not reveal its upload input'
    save(path,form,{'EventDate':day(-27),'EventDetails':'Photo added — CI photo and observation note'},
         files={'UploadedFiles':str(HERE/'action-photo.png')})
    event_id=event_record('CI photo and observation note','OBS_PHOTO',day(-27))
    rows=sql(f'SELECT plantPhotoId,fileName,thumbnailFileName,mimeType FROM orchids.plantphoto WHERE plantId={parent()} AND plantEventId={event_id} AND isActive=1;').splitlines()
    assert len(rows)==1,'Expected one photo attached to the observation'
    photo_id,original,thumbnail,mime=rows[0].split('\t');assert mime=='image/jpeg'
    hashes=[]
    for name,limit in [(original,1600),(thumbnail,300)]:
        assert name and name!='NULL'
        response=fetch(f'/uploads/plants/{parent()}/'+quote(name))
        assert response['status']==200
        data=Path(f'/specimen/uploads/plants/{parent()}/{name}').read_bytes()
        assert data==response['bytes']
        dimensions=jpeg_dimensions(data);assert max(dimensions)<=limit
        hashes.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'dimensions':dimensions})
    S['photo_files']=hashes
    return {'event_id':event_id,'photo_id':int(photo_id),'files':hashes,'note_and_photo_share_event':True}
check('Observation quick action: photo with a note',photo_note)

def move():
    before=int(sql(f'SELECT plantLocationHistoryId FROM orchids.plantlocationhistory WHERE plantId={parent()} AND isActive=1 AND endDateTime IS NULL;'))
    path=action('LocationChange');form=get_form(path,field='LocationId')
    save(path,form,{'LocationId':str(locations[1]),'EventDate':day(-20),
                    'EventDetails':'CI move to second location','PlantLocationNotes':'CI move location notes'})
    current=sql(f'SELECT locationId,DATE(locationStartDateTime) FROM orchids.vplantcurrentlocation WHERE plantId={parent()};').split('\t')
    assert current==[str(locations[1]),day(-20)],current
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plantlocationhistory WHERE plantLocationHistoryId={before} AND endDateTime IS NOT NULL AND DATE(endDateTime)<=\'{day(-20)}\';'))==1
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plantlocationhistory WHERE plantId={parent()} AND isActive=1 AND endDateTime IS NULL;'))==1
    details_contain('CI move to second location');details_contain('CI initial placement')
    S['destination']=locations[1]
    return {'previous_history_id':before,'new_location':locations[1],'previous_interval_closed':True,'one_current_location':True}
check('Move plant and preserve previous location history',move)

def flowering_closed():
    path=action('Flowering');form=get_form(path,field='StartDate')
    save(path,form,{'StartDate':day(-12),'EndDate':day(-10),'SpikeCount':'2','FlowerCount':'7',
                    'EventDetails':'CI completed flowering'})
    row=sql(f"SELECT floweringId,DATE(startDate),DATE(endDate),spikeCount,flowerCount FROM orchids.flowering WHERE plantId={parent()} AND floweringNotes='CI completed flowering' AND isActive=1;").split('\t')
    assert row[1:]==[day(-12),day(-10),'2','7'],row[1:]
    details_contain('CI completed flowering')
    report=fetch('/Reports/FloweringHistory');assert report['status']==200 and S['parent_tag'] in report['body']
    return {'flowering_id':int(row[0]),'dates_counts_and_notes_verified':True,'history_report_verified':True}
check('Flowering: save a completed period and counts',flowering_closed)

def flowering_open():
    path=action('Flowering');form=get_form(path,field='StartDate')
    save(path,form,{'StartDate':day(-8),'EndDate':'','SpikeCount':'1','FlowerCount':'4','EventDetails':'CI open flowering'})
    row=sql(f"SELECT floweringId,DATE(startDate),endDate FROM orchids.flowering WHERE plantId={parent()} AND floweringNotes='CI open flowering' AND isActive=1;").split('\t')
    assert row[1:]==[day(-8),'NULL'];S['open_flowering']=int(row[0])
    assert int(sql(f'SELECT COUNT(*) FROM orchids.vplantcurrentlyflowering WHERE plantId={parent()};'))==1
    r=fetch('/Reports/Flowering');assert r['status']==200 and S['parent_tag'] in r['body']
    return {'flowering_id':S['open_flowering'],'open_end_date':True,'currently_flowering_report_verified':True}
check('Flowering: start an open period',flowering_open)

def flowering_close():
    assert 'open_flowering' in S,'Open flowering was not created'
    path=f'/Plants/Events/Edit/{parent()}/{S["open_flowering"]}?eventType=Flowering'
    form=get_form(path,field='EndDate')
    save(path,form,{'EndDate':day(-5),'EventDetails':'CI open flowering now completed'})
    assert sql(f'SELECT DATE(endDate) FROM orchids.flowering WHERE floweringId={S["open_flowering"]};')==day(-5)
    assert int(sql(f'SELECT COUNT(*) FROM orchids.vplantcurrentlyflowering WHERE plantId={parent()};'))==0
    assert get_form(path,field='EndDate')['fields']['EndDate']==day(-5)
    details_contain('CI open flowering now completed')
    return {'flowering_id':S['open_flowering'],'end_saved_and_reopened':True,'no_longer_currently_flowering':True}
check('Flowering: finish the open period through its edit form',flowering_close)

def repot():
    path=action('Repotting');form=get_form(path,field='NewGrowthMediumId')
    changes={'EventDate':day(-3),'OldGrowthMediumId':str(media[0]),'NewGrowthMediumId':str(media[1]),
             'OldMediumNotes':'CI old medium condition','NewMediumNotes':'CI new medium mix',
             'PotSize':'12 cm','RepotReasonNotes':'CI repot reason','RepottingNotes':'CI repot additional notes'}
    save(path,form,changes)
    row=sql(f"SELECT repottingId,DATE(repotDate),oldGrowthMediumId,newGrowthMediumId,potSize,oldMediumNotes,newMediumNotes,repotReasonNotes,repottingNotes FROM orchids.repotting WHERE plantId={parent()} AND repottingNotes='CI repot additional notes' AND isActive=1;").split('\t')
    assert row[1:]==[day(-3),str(media[0]),str(media[1]),'12 cm',changes['OldMediumNotes'],changes['NewMediumNotes'],changes['RepotReasonNotes'],changes['RepottingNotes']]
    assert int(sql(f'SELECT growthMediumId FROM orchids.vplantcurrentgrowthmedium WHERE plantId={parent()};'))==media[1]
    path=f'/Plants/Events/Edit/{parent()}/{row[0]}?eventType=Repotting'
    reopened=get_form(path,field='NewGrowthMediumId')
    assert reopened['fields']['NewGrowthMediumId']==str(media[1]) and reopened['fields']['PotSize']=='12 cm'
    details_contain('CI repot additional notes');S['repot_id']=int(row[0])
    return {'repotting_id':int(row[0]),'old_new_media_dates_notes_pot_verified':True,'reopened_form_verified':True}
check('Repotting: save medium, pot size and notes',repot)

def rejected(kind,field,changes,table,phrase):
    path=action(kind);form=get_form(path,field=field)
    before=sql(f'SELECT COUNT(*) FROM orchids.{table} WHERE plantId={parent()};')
    response=fetch(path,data={**form['fields'],**changes})
    assert response['status']==200 and phrase.lower() in response['body'].lower(),'Expected validation error was not rendered'
    assert sql(f'SELECT COUNT(*) FROM orchids.{table} WHERE plantId={parent()};')==before,'Invalid input changed row count'
    return {'validation_message_seen':True,'new_records':0}
check('Observation rejects a future date',lambda:rejected('Observation','EventDetails',{'EventDate':day(1),'EventDetails':'CI invalid future observation'},'plantevent','cannot be in the future'))
check('Move rejects an absent location',lambda:rejected('LocationChange','LocationId',{'EventDate':day(-1),'LocationId':''},'plantlocationhistory','Please select a location'))
check('Flowering rejects an end before its start',lambda:rejected('Flowering','StartDate',{'StartDate':day(-4),'EndDate':day(-6),'EventDetails':'CI invalid flowering'},'flowering','End date cannot be before start date'))
check('Repotting rejects an absent new medium',lambda:rejected('Repotting','NewGrowthMediumId',{'EventDate':day(-1),'NewGrowthMediumId':''},'repotting','Please select a growth medium'))

def split_form():
    path=f'/Plants/Events/Split/{parent()}'
    form=get_form(path,field='ChildCount')
    submitter=next(b for b in form['submitters'] if parse_qs(urlsplit(b.get('formaction','')).query).get('handler')==['Split'])
    form['action']=submitter['formaction']
    return path,form

def split_reject_future():
    path,form=split_form()
    count=sql('SELECT COUNT(*) FROM orchids.plant;')
    response=fetch(form['action'],data={**form['fields'],'SplitDateTime':day(1),'ChildCount':'2'})
    assert response['status']==200 and 'Split date cannot be in the future' in response['body']
    assert sql('SELECT COUNT(*) FROM orchids.plant;')==count
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plantsplit WHERE parentPlantId={parent()};'))==0
    return {'validation_message_seen':True,'child_plants_created':0}
check('Split rejects a future date without creating children',split_reject_future)

def split_two():
    path,form=split_form();before=int(sql('SELECT COUNT(*) FROM orchids.plant;'))
    changes={'SplitDateTime':day(0),'ChildCount':'2','SplitReasonNotes':'CI split into two reason',
         'SplitNotes':'CI split into two notes','Children[0].PlantName':'CI split child A',
         'Children[0].MediumId':str(media[0]),'Children[1].PlantName':'CI split child B',
         'Children[1].MediumId':str(media[1])}
    confirmation=save(path,form,changes)
    assert 'Plant split completed' in confirmation['body'],'Split confirmation not rendered'
    assert int(sql('SELECT COUNT(*) FROM orchids.plant;'))==before+2,'Split did not create exactly two plants'
    rows=sql(f'SELECT c.childPlantId,p.plantName,p.plantTag,p.taxonId,p.isActive,p.endDate FROM orchids.plantsplitchild c JOIN orchids.plantsplit s ON s.plantSplitId=c.plantSplitId JOIN orchids.plant p ON p.plantId=c.childPlantId WHERE s.parentPlantId={parent()} ORDER BY c.childPlantId;').splitlines()
    assert len(rows)==2
    children=[r.split('\t') for r in rows]
    S['children']=[int(r[0]) for r in children]
    assert {r[1] for r in children}=={'CI split child A','CI split child B'}
    assert len({r[2] for r in children})==2 and all(r[2]!=S['parent_tag'] for r in children)
    assert all(r[3:]==[str(taxon),'1','NULL'] for r in children)
    assert sql(f'SELECT DATE(endDate) FROM orchids.plant WHERE plantId={parent()};')==day(0)
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plant p JOIN orchids.plantsplit s ON s.parentPlantId=p.plantId JOIN orchids.plantsplitchild c ON c.plantSplitId=s.plantSplitId JOIN orchids.plant child ON child.plantId=c.childPlantId WHERE p.plantId={parent()} AND p.endDate=s.splitDateTime AND child.acquisitionDate=s.splitDateTime;'))==2
    assert int(sql(f'SELECT COUNT(*) FROM orchids.plantlocationhistory l JOIN orchids.plant p ON p.plantId=l.plantId WHERE p.plantId={parent()} AND l.endDateTime=p.endDate;'))==1
    assert sql(f'SELECT splitReasonNotes,splitNotes FROM orchids.plantsplit WHERE parentPlantId={parent()};')=='CI split into two reason\tCI split into two notes'
    parent_lineage=fetch(f'/Plants/Lineage/{parent()}');assert parent_lineage['status']==200
    parent_details=fetch(f'/Plants/Details/{parent()}');assert parent_details['status']==200
    for child in children:
        child_id=int(child[0]);expected_medium=media[0] if child[1].endswith('A') else media[1]
        # The documented split contract gives children no location initially.
        assert sql(f'SELECT locationId FROM orchids.vplantcurrentlocation WHERE plantId={child_id};')=='NULL'
        assert int(sql(f'SELECT growthMediumId FROM orchids.vplantcurrentgrowthmedium WHERE plantId={child_id};'))==expected_medium
        assert int(sql(f'SELECT COUNT(*) FROM orchids.vplantlineage WHERE parentPlantId={parent()} AND childPlantId={child_id};'))==1
        assert child[2] in parent_details['body']
        child_lineage=fetch(f'/Plants/Lineage/{child_id}')
        assert child_lineage['status']==200 and S['parent_tag'] in child_lineage['body']
        assert fetch(f'/Plants/Details/{child_id}')['status']==200
    details_contain('CI standalone observation note');details_contain('CI photo and observation note')
    return {'parent_id':parent(),'parent_ended':True,'children':S['children'],
            'distinct_permanent_tags':True,'lineage_both_directions':True,
            'children_initially_unlocated_as_documented':True,'selected_media_verified':True,
            'split_notes_saved':True,'parent_history_preserved':True,
            'review_of_existing_completed_split':False}
check('Split parent into exactly two independent plants',split_two)

def integrity():
    assert sql(history_query)==history_before
    return {'active_history_rows':len(history_before.splitlines()),'history_unchanged_during_actions':True}
check('Active migration history remains unchanged during application actions',integrity)

report={'scope':'Current self-contained Linux ARM64 package against upgraded historical specimen through actual HTTP forms',
        'checks':RESULTS,'passed':sum(r['result']=='passed' for r in RESULTS),
        'failed':sum(r['result']=='failed' for r in RESULTS),'state':S,
        'limits':['No browser JavaScript/visual click or real Pi/systemd testing','Selected acceptance cases, not exhaustive application coverage']}
(HERE/'actions-report.json').write_text(json.dumps(report,indent=2))
raise SystemExit(1 if report['failed'] else 0)
