import argparse
import email
import email.message
import imaplib
import json
import logging
import os
from email.header import decode_header
from getpass import getpass
from pathlib import Path
from typing import Any


PASSWORD_ENVIRONMENT_VARIABLE = "ORCHIDAPP_IMAP_PASSWORD"


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


def load_config(config_path: Path) -> dict[str, Any]:
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with config_path.open("r", encoding="utf-8") as config_file:
        return json.load(config_file)


def get_required_config_value(config: dict[str, Any], key: str) -> Any:
    value = config.get(key)

    if value is None or value == "":
        raise ValueError(f"Missing required config value: {key}")

    return value


def is_matching_sensor_email(
    sender: str,
    subject: str,
    expected_sender: str,
    expected_subject: str
) -> bool:
    return (
        expected_sender.lower() in sender.lower()
        and subject.strip() == expected_subject
    )


def is_csv_attachment(filename: str) -> bool:
    return filename.lower().endswith(".csv")


def get_safe_download_path(download_directory: Path, filename: str) -> Path:
    # Keep only the final filename component to prevent path traversal.
    safe_filename = Path(filename).name
    return download_directory / safe_filename


def download_attachments(
    message: email.message.Message,
    download_directory: Path
) -> list[Path]:
    downloaded_files: list[Path] = []

    for part in message.walk():
        if part.get_content_disposition() != "attachment":
            continue

        raw_filename = part.get_filename()
        filename = normalise_filename(decode_mime_header(raw_filename))

        if not filename:
            continue

        if not is_csv_attachment(filename):
            logging.info("Skipping non-CSV attachment: %s", filename)
            continue

        payload = part.get_payload(decode=True)
        if payload is None:
            logging.warning("Skipping attachment with no payload: %s", filename)
            continue

        download_path = get_safe_download_path(download_directory, filename)
        download_path.write_bytes(payload)
        downloaded_files.append(download_path)

    return downloaded_files


def move_message_to_processed(
    mail: imaplib.IMAP4_SSL,
    message_id: bytes,
    processed_mailbox: str
) -> None:
    mail.store(message_id, "+FLAGS", "\\Seen")

    copy_status, _ = mail.copy(message_id, processed_mailbox)
    if copy_status != "OK":
        raise RuntimeError(
            f"Unable to copy message {message_id.decode()} "
            f"to {processed_mailbox}."
        )

    mail.store(message_id, "+FLAGS", "\\Deleted")
    logging.info("Message queued to move to %s.", processed_mailbox)


def get_imap_password() -> str:
    password = os.environ.get(PASSWORD_ENVIRONMENT_VARIABLE)

    if password:
        return password

    # Dev fallback only. The Pi/systemd service should use the environment file.
    return getpass("GMX password: ")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download OrchidApp environment CSV emails from IMAP."
    )

    parser.add_argument(
        "--config",
        required=True,
        help="Path to the environment importer JSON config file."
    )

    return parser.parse_args()


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s"
    )

    args = parse_args()
    config_path = Path(args.config)

    config = load_config(config_path)

    imap_host = get_required_config_value(config, "imapHost")
    imap_port = int(get_required_config_value(config, "imapPort"))
    imap_user = get_required_config_value(config, "imapUser")
    mailbox = get_required_config_value(config, "mailbox")
    processed_mailbox = get_required_config_value(config, "processedMailbox")
    expected_sender = get_required_config_value(config, "expectedSender")
    expected_subject = get_required_config_value(config, "expectedSubject")
    download_directory = Path(
        get_required_config_value(config, "downloadDirectory")
    )

    password = get_imap_password()

    download_directory.mkdir(parents=True, exist_ok=True)

    logging.info("Connecting to IMAP server %s:%s...", imap_host, imap_port)

    with imaplib.IMAP4_SSL(imap_host, imap_port) as mail:
        mail.login(imap_user, password)

        logging.info("Connected successfully.")
        logging.info("Opening mailbox: %s", mailbox)

        status, _ = mail.select(mailbox, readonly=False)
        if status != "OK":
            raise RuntimeError(f"Unable to open mailbox: {mailbox}")

        status, data = mail.search(None, "UNSEEN")
        if status != "OK":
            raise RuntimeError("Unable to search mailbox.")

        message_ids = data[0].split()
        logging.info("Unread messages found: %s", len(message_ids))

        matching_messages = 0
        downloaded_count = 0

        for message_id in message_ids:
            status, message_data = mail.fetch(message_id, "(RFC822)")
            if status != "OK":
                logging.warning(
                    "Could not fetch message ID %s",
                    message_id.decode()
                )
                continue

            raw_message = message_data[0][1]
            message = email.message_from_bytes(raw_message)

            subject = decode_mime_header(message.get("Subject"))
            sender = decode_mime_header(message.get("From"))
            date = decode_mime_header(message.get("Date"))

            if not is_matching_sensor_email(
                sender,
                subject,
                expected_sender,
                expected_subject
            ):
                continue

            matching_messages += 1

            logging.info("Processing message ID: %s", message_id.decode())
            logging.info("From: %s", sender)
            logging.info("Date: %s", date)
            logging.info("Subject: %s", subject)

            downloaded_files = download_attachments(message, download_directory)

            if downloaded_files:
                for downloaded_file in downloaded_files:
                    downloaded_count += 1
                    logging.info("Downloaded: %s", downloaded_file)

                move_message_to_processed(
                    mail,
                    message_id,
                    processed_mailbox
                )
            else:
                logging.info("No CSV attachments downloaded.")
                logging.info("Message left in inbox.")

        mail.expunge()
        logging.info("Mailbox housekeeping completed.")

        mail.logout()

    logging.info("Matching messages: %s", matching_messages)
    logging.info("CSV attachments downloaded: %s", downloaded_count)
    logging.info("Finished.")


if __name__ == "__main__":
    main()