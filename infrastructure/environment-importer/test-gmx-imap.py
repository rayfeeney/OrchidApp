import email
import imaplib
from email.header import decode_header
from getpass import getpass
from pathlib import Path


IMAP_HOST = "imap.gmx.com"
IMAP_PORT = 993
IMAP_USER = "orchidappdata@gmx.co.uk"

MAILBOX = "INBOX"
PROCESSED_MAILBOX = "OrchidAppProcessed"

EXPECTED_SENDER = "no-reply@govee.com"
EXPECTED_SUBJECT = "Data"

SCRIPT_DIR = Path(__file__).resolve().parent
DOWNLOAD_DIR = SCRIPT_DIR / "downloads"


def decode_mime_header(value: str | None) -> str:
    if not value:
        return ""

    decoded_parts: list[str] = []

    for text, encoding in decode_header(value):
        if isinstance(text, bytes):
            decoded_parts.append(
                text.decode(encoding or "utf-8", errors="replace")
            )
        else:
            decoded_parts.append(text)

    return "".join(decoded_parts)


def normalise_filename(filename: str) -> str:
    return " ".join(filename.split())


def is_matching_sensor_email(sender: str, subject: str) -> bool:
    return (
        EXPECTED_SENDER in sender.lower()
        and subject.strip() == EXPECTED_SUBJECT
    )


def is_csv_attachment(filename: str) -> bool:
    return filename.lower().endswith(".csv")


def get_safe_download_path(filename: str) -> Path:
    # Keep only the final filename component to prevent path traversal.
    safe_filename = Path(filename).name
    return DOWNLOAD_DIR / safe_filename


def download_attachments(message: email.message.Message) -> list[Path]:
    downloaded_files: list[Path] = []

    for part in message.walk():
        if part.get_content_disposition() != "attachment":
            continue

        raw_filename = part.get_filename()
        filename = normalise_filename(decode_mime_header(raw_filename))

        if not filename:
            continue

        if not is_csv_attachment(filename):
            print(f"Skipping non-CSV attachment: {filename}")
            continue

        payload = part.get_payload(decode=True)
        if payload is None:
            print(f"Skipping attachment with no payload: {filename}")
            continue

        download_path = get_safe_download_path(filename)
        download_path.write_bytes(payload)
        downloaded_files.append(download_path)

    return downloaded_files


def move_message_to_processed(
    mail: imaplib.IMAP4_SSL,
    message_id: bytes
) -> None:
    mail.store(message_id, "+FLAGS", "\\Seen")

    copy_status, _ = mail.copy(message_id, PROCESSED_MAILBOX)
    if copy_status != "OK":
        raise RuntimeError(
            f"Unable to copy message {message_id.decode()} "
            f"to {PROCESSED_MAILBOX}."
        )

    mail.store(message_id, "+FLAGS", "\\Deleted")
    print(f"Message queued to move to {PROCESSED_MAILBOX}.")


def main() -> None:
    password = getpass("GMX password: ")

    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)

    print("Connecting to GMX IMAP...")

    with imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT) as mail:
        mail.login(IMAP_USER, password)

        print("Connected successfully.")
        print(f"Opening mailbox: {MAILBOX}")

        status, _ = mail.select(MAILBOX, readonly=False)
        if status != "OK":
            raise RuntimeError(f"Unable to open mailbox: {MAILBOX}")

        status, data = mail.search(None, "UNSEEN")
        if status != "OK":
            raise RuntimeError("Unable to search mailbox.")

        message_ids = data[0].split()
        print(f"Unread messages found: {len(message_ids)}")

        latest_message_ids = message_ids[-10:]
        matching_messages = 0
        downloaded_count = 0

        for message_id in latest_message_ids:
            status, message_data = mail.fetch(message_id, "(RFC822)")
            if status != "OK":
                print(f"Could not fetch message ID {message_id.decode()}")
                continue

            raw_message = message_data[0][1]
            message = email.message_from_bytes(raw_message)

            subject = decode_mime_header(message.get("Subject"))
            sender = decode_mime_header(message.get("From"))
            date = decode_mime_header(message.get("Date"))

            if not is_matching_sensor_email(sender, subject):
                continue

            matching_messages += 1

            print()
            print(f"Message ID:  {message_id.decode()}")
            print(f"From:        {sender}")
            print(f"Date:        {date}")
            print(f"Subject:     {subject}")

            downloaded_files = download_attachments(message)

            if downloaded_files:
                print("Downloaded attachments:")
                for downloaded_file in downloaded_files:
                    downloaded_count += 1
                    print(f"  - {downloaded_file}")

                move_message_to_processed(mail, message_id)
            else:
                print("Downloaded attachments: none")
                print("Message left in inbox.")

        mail.expunge()
        print("Mailbox housekeeping completed.")

        mail.logout()

    print()
    print(f"Matching messages: {matching_messages}")
    print(f"CSV attachments downloaded: {downloaded_count}")
    print("Finished.")


if __name__ == "__main__":
    main()