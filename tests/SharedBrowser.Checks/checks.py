"""Shared browser acceptance against an explicitly selected disposable OrchidApp."""
import argparse
from datetime import date, timedelta
from pathlib import Path
import re
from urllib.parse import urlsplit
from uuid import uuid4

from playwright.sync_api import expect, sync_playwright


def check_readiness(page, base_url):
    result = page.request.get(base_url + "/health/ready", max_redirects=0)
    report = result.json()
    assert result.status == 200, f"Readiness returned HTTP {result.status}: {report}"
    assert report["ready"] and report["checks"] and all(report["checks"].values()), report


def open_plant_from_search(page, base_url, name, plant_id):
    page.goto(base_url + "/Search")
    search = page.locator('form[aria-label="Search botanical names"]')
    search.locator('input[name="q"]').fill(name)
    search.locator('input[name="q"]').press("Enter")
    result = page.locator(f"#result-plant-{plant_id}")
    expect(result).to_contain_text(name)
    result.click()
    expect(page).to_have_url(re.compile(rf"/Plants/Details/{plant_id}(?:[?#]|$)"))
    expect(page.locator("h1")).to_be_visible()


def check_gallery(page, base_url, plant_id):
    page.goto(f"{base_url}/Plants/Photos/{plant_id}")
    thumbnails = page.locator('a:has(img[src*="/uploads/"])')
    expect(thumbnails).to_have_count(2)
    originals = set()
    for item in range(2):
        thumb = thumbnails.nth(item).locator("img")
        expect(thumb).to_have_js_property("complete", True)
        assert thumb.evaluate("(image) => image.naturalWidth > 0"), "Thumbnail did not decode"
        thumb_url = thumb.get_attribute("src")
        thumbnails.nth(item).click()
        original = page.locator('img.img-fluid[src*="/uploads/"]')
        expect(original).to_have_js_property("complete", True)
        assert original.evaluate("(image) => image.naturalWidth > 0"), "Original did not decode"
        original_url = original.get_attribute("src")
        assert original_url != thumb_url, "Gallery reused original in place of thumbnail"
        originals.add(original_url)
    assert len(originals) == 2, "The two uploads did not produce distinct originals"


def exercise(page, args):
    base = args.base_url
    check_readiness(page, base)
    page.goto(base + "/")
    expect(page.locator("h1")).to_be_visible()
    if args.reopen:
        plant_id, name = args.reopen
        assert re.fullmatch(r"[1-9][0-9]*", plant_id), "Invalid plant ID"
        open_plant_from_search(page, base, name, plant_id)
        check_gallery(page, base, plant_id)
        return

    name = "Browserfixture" + uuid4().hex[:12]
    page.goto(base + "/Plants/Add")
    link = page.locator('a[href*="/Plants/Add/Create/"]').first
    # Start from the published form route without a return target, so Continue opens Details.
    path = urlsplit(link.get_attribute("href")).path
    page.goto(base + path)
    page.locator('[name="Input.PlantName"]').fill(name)
    page.locator('[name="Input.AcquisitionDate"]').fill("2020-01-01")
    page.get_by_role("button", name="Add plant", exact=True).click()
    expect(page.locator("h1")).to_have_text("Plant added")
    expect(page.get_by_text(name, exact=True)).to_be_visible()
    plant_id = urlsplit(page.url).path.rsplit("/", 1)[1]
    assert re.fullmatch(r"[1-9][0-9]*", plant_id), "Create did not return a plant ID"
    page.get_by_role("link", name="Continue", exact=True).click()
    expect(page).to_have_url(re.compile(rf"/Plants/Details/{plant_id}(?:[?#]|$)"))

    page.get_by_role("link", name="Edit", exact=True).click()
    edited = name + "edited"
    page.locator('input[name="PlantName"]').fill(edited)
    page.get_by_role("button", name="Save changes", exact=True).click()
    open_plant_from_search(page, base, edited, plant_id)
    page.locator(f'a[href*="/Plants/Events/Add/{plant_id}/Observation"]').click()
    event_url = page.url
    marker = "Observation " + name
    page.locator('[name="EventDate"]').fill((date.today() + timedelta(days=7)).isoformat())
    page.locator('[name="EventDetails"]').fill(marker)
    page.locator('form:has([name="EventDate"]) button.btn-primary[type="submit"]').click()
    expect(page.locator('[data-valmsg-for="EventDate"]')).to_contain_text("future")
    witness = page.context.new_page()
    try:
        witness.goto(f"{base}/Plants/Details/{plant_id}")
        expect(witness.locator("h1")).to_be_visible()
        expect(witness.get_by_text(marker, exact=False)).to_have_count(0)
    finally:
        witness.close()
    assert urlsplit(page.url).path == urlsplit(event_url).path
    page.locator('[name="EventDate"]').fill((date.today() - timedelta(days=2)).isoformat())
    page.locator('[name="EventDetails"]').fill(marker)
    page.locator('form:has([name="EventDate"]) button.btn-primary[type="submit"]').click()
    page.goto(f"{base}/Plants/Details/{plant_id}")
    expect(page.get_by_text(marker, exact=False)).to_have_count(1)

    page.goto(f"{base}/Plants/Photos/{plant_id}")
    page.locator('input[name="UploadFiles"]').set_input_files([args.jpeg, args.heic])
    page.get_by_role("button", name="Upload photos").click()
    expect(page.locator('a:has(img[src*="/uploads/"])')).to_have_count(2)
    check_gallery(page, base, plant_id)
    print(f"Reopen after restart with --reopen {plant_id} {edited}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--disposable", action="store_true", help="Confirm this app and its database/uploads are disposable")
    parser.add_argument("--jpeg", type=Path)
    parser.add_argument("--heic", type=Path)
    parser.add_argument("--reopen", nargs=2, metavar=("PLANT_ID", "PLANT_NAME"))
    args = parser.parse_args()
    parsed = urlsplit(args.base_url)
    if (not args.disposable or parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
            or not parsed.port or parsed.netloc != f"127.0.0.1:{parsed.port}"
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
        parser.error("Select an explicit disposable installation at http://127.0.0.1:PORT")
    args.base_url = f"http://{parsed.netloc}"
    if not args.reopen and not all(path and path.is_file() for path in (args.jpeg, args.heic)):
        parser.error("Provide both local synthetic --jpeg and --heic files")
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        try:
            context = browser.new_context()
            context.route("**/*", lambda route: route.continue_()
                          if route.request.url.startswith(args.base_url + "/") else route.abort())
            try:
                exercise(context.new_page(), args)
            finally:
                context.close()
        finally:
            browser.close()
    print("Shared browser checks passed")


if __name__ == "__main__":
    main()
