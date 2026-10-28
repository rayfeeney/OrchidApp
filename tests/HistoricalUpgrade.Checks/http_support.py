"""Actual loopback HTTP forms inside the owned, network-none fixture namespace."""
from html.parser import HTMLParser
import hashlib, json, os, re, struct, subprocess, time, zlib
from pathlib import Path
from urllib.parse import urlencode, urljoin, urlsplit, quote
from urllib.request import build_opener, HTTPCookieProcessor, HTTPRedirectHandler, Request
from urllib.error import HTTPError
from http.cookiejar import CookieJar
HERE=Path(os.environ['ORCHID_ACTION_OUTPUT']);HERE.mkdir(parents=True,exist_ok=True)
BASE='http://127.0.0.1:5080'
RESULTS=[]
class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None
OPENER=build_opener(HTTPCookieProcessor(CookieJar()),NoRedirect())
def sql(text):
    p=subprocess.run(['mariadb','--defaults-extra-file=/specimen/admin.cnf','--batch','--skip-column-names','--raw'],input=text.encode(),capture_output=True,timeout=90)
    if p.returncode: raise RuntimeError('Fixture SQL failed')
    return p.stdout.decode().strip()
class Forms(HTMLParser):
    def __init__(self,text):
        super().__init__(convert_charrefs=True)
        self.forms=[];self.current=None;self.textarea=None;self.select=None
        self.feed(text)
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='form':
            self.current={'action':a.get('action',''),'method':a.get('method','get'),
                          'fields':{},'files':[],'submitters':[]}
            self.forms.append(self.current)
        if self.current is None:return
        fields=self.current['fields']
        if tag=='button' and a.get('type','submit').lower()=='submit':
            self.current['submitters'].append(a)
        if tag=='input' and a.get('name') and 'disabled' not in a:
            name=a['name'];kind=a.get('type','text').lower()
            if kind=='file':self.current['files'].append(name)
            elif kind not in ['submit','button','reset','image'] and (kind not in ['checkbox','radio'] or 'checked' in a):
                fields.setdefault(name,a.get('value',''))
        elif tag=='textarea' and a.get('name') and 'disabled' not in a:
            self.textarea=a['name'];fields[self.textarea]=''
        elif tag=='select' and a.get('name') and 'disabled' not in a:
            self.select={'name':a['name'],'first':None,'chosen':None}
        elif tag=='option' and self.select is not None:
            value=a.get('value','')
            if self.select['first'] is None:self.select['first']=value
            if 'selected' in a:self.select['chosen']=value
    def handle_data(self,data):
        if self.current is not None and self.textarea is not None:
            self.current['fields'][self.textarea]+=data
    def handle_endtag(self,tag):
        if tag=='textarea':self.textarea=None
        elif tag=='select' and self.select is not None:
            self.current['fields'][self.select['name']]=self.select['chosen'] if self.select['chosen'] is not None else (self.select['first'] or '')
            self.select=None
        elif tag=='form':self.current=None

def fetch(path,data=None,multipart=None):
    url=urljoin(BASE,path)
    if urlsplit(url).netloc!='127.0.0.1:5080' or urlsplit(url).scheme!='http':raise ValueError('External HTTP target refused')
    payload=None;headers={}
    if multipart is not None:
        boundary='OrchidHistoricalFixtureBoundary'
        chunks=[]
        for key,value in data.items():
            chunks.append(('--'+boundary+'\r\nContent-Disposition: form-data; name="'+key+'"\r\n\r\n'+value+'\r\n').encode())
        for key,name in multipart.items():
            chunks += [('--'+boundary+'\r\nContent-Disposition: form-data; name="'+key+'"; filename="action-photo.png"\r\nContent-Type: image/png\r\n\r\n').encode(),Path(name).read_bytes(),b'\r\n']
        chunks.append(('--'+boundary+'--\r\n').encode());payload=b''.join(chunks)
        headers['Content-Type']='multipart/form-data; boundary='+boundary
    elif data is not None:
        payload=urlencode(data).encode();headers['Content-Type']='application/x-www-form-urlencoded'
    request=Request(url,data=payload,headers=headers)
    try:response=OPENER.open(request,timeout=60)
    except HTTPError as error:response=error
    with response:
        raw=response.read();status=response.code;returned_headers=str(response.headers)
    return {'status':status,'body':raw.decode('utf-8','replace'),'bytes':raw,'headers':returned_headers,'url':url}

def get_form(path,field=None,file=None):
    response=fetch(path)
    assert response['status']==200,f'Form GET returned {response["status"]}'
    forms=Forms(response['body']).forms
    selected=next(f for f in forms if (field is None or field in f['fields']) and
                  (file is None or file in f['files']) and f['method'].lower()=='post')
    assert selected['fields'].get('__RequestVerificationToken'),'Antiforgery token missing'
    return selected

def save(path,form,changes,files=None):
    fields=dict(form['fields']);fields.update(changes)
    target=urljoin(urljoin(BASE,path),form['action'] or path)
    result=fetch(target,data=fields,multipart=files)
    if result['status'] not in [302,303]:
        (HERE/'last-form-response.html').write_text(result['body'],encoding='utf-8')
        raise AssertionError(f'Save returned HTTP {result["status"]}; response retained')
    location=next((s.split(':',1)[1].strip() for s in result['headers'].splitlines() if s.lower().startswith('location:')),None)
    assert location,'Save redirect missing'
    reopened=fetch(location)
    assert reopened['status']==200,f'Redirected page returned {reopened["status"]}'
    return reopened

def check(name,fn):
    try:
        detail=fn();RESULTS.append({'name':name,'result':'passed','detail':detail});print('PASS: '+name,flush=True)
    except Exception as error:
        RESULTS.append({'name':name,'result':'failed','error':str(error)});print('FAIL: '+name+' '+str(error),flush=True)
    (HERE/'actions-report.json').write_text(json.dumps({'checks':RESULTS},indent=2))

def make_photo(path):
    w,h=800,500
    raw=b''.join(b'\x00'+b''.join(bytes((x%256,y%256,(x+y)%256)) for x in range(w)) for y in range(h))
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def jpeg_dimensions(data):
    if not data.startswith(b'\xff\xd8'):raise ValueError('Not JPEG')
    i=2
    while i<len(data):
        if data[i]!=255:raise ValueError('Invalid JPEG marker')
        while data[i]==255:i+=1
        marker=data[i];i+=1
        if marker in (0xd8,0xd9) or 0xd0<=marker<=0xd7:continue
        size=int.from_bytes(data[i:i+2],'big')
        if marker in (0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf):
            height,width=struct.unpack('>HH',data[i+3:i+7]);return [width,height]
        i+=size
    raise ValueError('JPEG dimensions missing')
