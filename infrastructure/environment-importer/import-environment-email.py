import argparse
import csv
import email
import email.message
import imaplib
import json
import logging
import os
import re
import mariadb
import hashlib
import shutil
from datetime import datetime
from email.header import decode_header
from getpass import getpass
from pathlib import Path
from typing import Any
batch_size = 1000

IMAP_PASSWORD_ENVIRONMENT_VARIABLE = "ORCHIDAPP_IMAP_PASSWORD"
DATABASE_PASSWORD_ENVIRONMENT_VARIABLE = "ORCHIDAPP_DATABASE_PASSWORD"

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


def parse_sensor_filename(filename: str) -> tuple[str, str]:
    match = re.match(r"^(.+)_export_([0-9]{12})\.csv$", filename)

    if not match:
        raise ValueError(f"Unexpected sensor filename format: {filename}")

    sensor_name = match.group(1).strip()
    file_timestamp_text = match.group(2)

    return sensor_name, file_timestamp_text


def parse_reading_datetime(value: str) -> datetime:
    value = value.strip()

    supported_formats = [
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%d/%m/%Y %H:%M:%S",
        "%d/%m/%Y %H:%M",
    ]

    for date_format in supported_formats:
        try:
            return datetime.strptime(value, date_format)
        except ValueError:
            continue

    raise ValueError(f"Unable to parse reading timestamp: {value}")


def inspect_csv_file(csv_path: Path) -> dict[str, Any]:
    filename = csv_path.name
    sensor_name, file_timestamp_text = parse_sensor_filename(filename)

    row_count = 0
    first_reading_datetime: datetime | None = None
    last_reading_datetime: datetime | None = None

    with csv_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)

        try:
            header = next(reader)
        except StopIteration:
            raise ValueError(f"CSV file is empty: {csv_path}")

        for row in reader:
            if not row or all(not value.strip() for value in row):
                continue

            if len(row) < 3:
                raise ValueError(
                    f"CSV row has fewer than 3 columns in {csv_path}: {row}"
                )

            reading_datetime = parse_reading_datetime(row[0])

            row_count += 1

            if first_reading_datetime is None:
                first_reading_datetime = reading_datetime
            else:
                first_reading_datetime = min(
                    first_reading_datetime,
                    reading_datetime
                )

            if last_reading_datetime is None:
                last_reading_datetime = reading_datetime
            else:
                last_reading_datetime = max(
                    last_reading_datetime,
                    reading_datetime
                )

    logging.info("CSV metadata:")
    logging.info("  File: %s", csv_path)
    logging.info("  Sensor name: %s", sensor_name)
    logging.info("  File timestamp text: %s", file_timestamp_text)
    logging.info("  Header: %s", header)
    logging.info("  Row count: %s", row_count)
    logging.info("  First reading datetime: %s", first_reading_datetime)
    logging.info("  Last reading datetime: %s", last_reading_datetime)

    return {
        "fileSensorName": sensor_name,
        "fileTimestampText": file_timestamp_text,
        "firstReadingDateTime": first_reading_datetime,
        "lastReadingDateTime": last_reading_datetime,
        "rowCount": row_count,
        "header": header,
    }


def get_safe_download_path(download_directory: Path, filename: str) -> Path:
    # Keep only the final filename component to prevent path traversal.
    safe_filename = Path(filename).name
    return download_directory / safe_filename


def get_unique_destination_path(destination_directory: Path, source_path: Path) -> Path:
    destination_path = destination_directory / source_path.name

    if not destination_path.exists():
        return destination_path

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return destination_directory / (
        f"{source_path.stem}_{timestamp}{source_path.suffix}"
    )


def move_csv_file(source_path: Path, destination_directory: Path) -> Path:
    destination_directory.mkdir(parents=True, exist_ok=True)

    destination_path = get_unique_destination_path(
        destination_directory,
        source_path,
    )

    shutil.move(str(source_path), str(destination_path))

    logging.info(
        "Moved CSV file from %s to %s.",
        source_path,
        destination_path,
    )

    return destination_path


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


def calculate_file_hash(file_path: Path) -> str:
    sha256 = hashlib.sha256()

    with file_path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            sha256.update(chunk)

    return sha256.hexdigest().upper()


def get_imap_password() -> str:
    password = os.environ.get(IMAP_PASSWORD_ENVIRONMENT_VARIABLE)

    if password:
        return password

    # Dev fallback only. The Pi/systemd service should use the environment file.
    return getpass("GMX password: ")


def get_database_password() -> str:
    password = os.environ.get(DATABASE_PASSWORD_ENVIRONMENT_VARIABLE)

    if password:
        return password

    # Dev fallback only. The Pi/systemd service should use the environment file.
    return getpass("MariaDB password: ")


def test_database_connection(config: dict[str, Any]) -> None:
    database_password = get_database_password()

    connection = mariadb.connect(
        host=get_required_config_value(config, "databaseHost"),
        port=int(get_required_config_value(config, "databasePort")),
        user=get_required_config_value(config, "databaseUser"),
        password=database_password,
        database=get_required_config_value(config, "databaseName"),
    )

    try:
        cursor = connection.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        logging.info("Database connection successful.")
    finally:
        connection.close()


def create_database_connection(config: dict[str, Any]) -> mariadb.Connection:
    database_password = get_database_password()

    return mariadb.connect(
        host=get_required_config_value(config, "databaseHost"),
        port=int(get_required_config_value(config, "databasePort")),
        user=get_required_config_value(config, "databaseUser"),
        password=database_password,
        database=get_required_config_value(config, "databaseName"),
    )


def clear_environment_import_rows(connection: mariadb.Connection) -> None:
    cursor = connection.cursor()
    cursor.execute("DELETE FROM environmentimportrow")
    logging.info("Cleared environmentimportrow.")


def insert_environment_import_file(
    connection: mariadb.Connection,
    file_path: Path,
    file_hash: str,
    file_sensor_name: str,
    file_timestamp_text: str,
    first_reading_datetime: datetime | None,
    last_reading_datetime: datetime | None,
    row_count: int,
) -> int:
    cursor = connection.cursor()

    cursor.execute(
        """
        INSERT INTO environmentimportfile (
            fileName,
            filePath,
            fileHash,
            fileSensorName,
            fileTimestampText,
            firstReadingDateTime,
            lastReadingDateTime,
            rowCount,
            status,
            importStartedAt,
            importCompletedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        """,
        (
            file_path.name,
            str(file_path),
            file_hash,
            file_sensor_name,
            file_timestamp_text,
            first_reading_datetime,
            last_reading_datetime,
            row_count,
            "LoadedToImportFile",
        ),
    )

    environment_import_file_id = cursor.lastrowid

    logging.info(
        "Inserted environmentimportfile row with ID %s.",
        environment_import_file_id,
    )

    return environment_import_file_id


def insert_environment_import_rows(
    connection: mariadb.Connection,
    environment_import_file_id: int,
    csv_path: Path,
) -> int:
    inserted_rows = 0

    with csv_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)

        try:
            next(reader)  # header row
        except StopIteration:
            raise ValueError(f"CSV file is empty: {csv_path}")

        rows_to_insert = []

        for source_row_number, row in enumerate(reader, start=2):
            if not row or all(not value.strip() for value in row):
                continue

            if len(row) < 3:
                raise ValueError(
                    f"CSV row has fewer than 3 columns in {csv_path} "
                    f"at source row {source_row_number}: {row}"
                )

            raw_timestamp_text = row[0].strip()
            raw_temperature_text = row[1].strip()
            raw_humidity_text = row[2].strip()

            reading_datetime = parse_reading_datetime(raw_timestamp_text)
            temperature_celsius = float(raw_temperature_text)
            relative_humidity = float(raw_humidity_text)

            rows_to_insert.append(
                (
                    environment_import_file_id,
                    source_row_number,
                    raw_timestamp_text,
                    raw_temperature_text,
                    raw_humidity_text,
                    reading_datetime,
                    temperature_celsius,
                    relative_humidity,
                )
            )

        if rows_to_insert:
            cursor = connection.cursor()

            insert_sql = """
                INSERT INTO environmentimportrow (
                    environmentImportFileId,
                    sourceRowNumber,
                    rawTimestampText,
                    rawTemperatureText,
                    rawHumidityText,
                    readingDateTime,
                    temperatureCelsius,
                    relativeHumidity
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

            for start_index in range(0, len(rows_to_insert), batch_size):
                batch = rows_to_insert[start_index:start_index + batch_size]
                cursor.executemany(insert_sql, batch)
                inserted_rows += len(batch)

                logging.info(
                    "Inserted environmentimportrow batch: %s rows total so far.",
                    inserted_rows,
                )

    logging.info(
        "Inserted %s rows into environmentimportrow.",
        inserted_rows,
    )

    return inserted_rows


def upsert_environment_readings(
    connection: mariadb.Connection,
    environment_import_file_id: int,
) -> None:
    cursor = connection.cursor()
    cursor.execute(
        "CALL spUpsertEnvironmentReadings(?)",
        (environment_import_file_id,),
    )

    logging.info(
        "Upserted environment readings for environmentImportFileId %s.",
        environment_import_file_id,
    )


def import_csv_file(
    config: dict[str, Any],
    csv_path: Path,
) -> int:
    logging.info("Importing CSV file: %s", csv_path)

    csv_metadata = inspect_csv_file(csv_path)
    file_hash = calculate_file_hash(csv_path)

    database_connection = create_database_connection(config)

    try:
        clear_environment_import_rows(database_connection)

        environment_import_file_id = insert_environment_import_file(
            database_connection,
            csv_path,
            file_hash,
            csv_metadata["fileSensorName"],
            csv_metadata["fileTimestampText"],
            csv_metadata["firstReadingDateTime"],
            csv_metadata["lastReadingDateTime"],
            csv_metadata["rowCount"],
        )

        insert_environment_import_rows(
            database_connection,
            environment_import_file_id,
            csv_path,
        )

        upsert_environment_readings(
            database_connection,
            environment_import_file_id,
        )

        database_connection.commit()

        logging.info(
            "Completed CSV import for environmentImportFileId %s.",
            environment_import_file_id,
        )

        return environment_import_file_id

    except Exception:
        database_connection.rollback()
        raise

    finally:
        database_connection.close()


def import_existing_csv_files(
    config: dict[str, Any],
    download_directory: Path,
    processed_directory: Path,
    failed_directory: Path,
) -> int:
    imported_file_count = 0

    csv_files = sorted(download_directory.glob("*.csv"))

    if not csv_files:
        logging.info(
            "No existing CSV files found in download directory: %s",
            download_directory,
        )
        return imported_file_count

    logging.info(
        "Existing CSV files found in download directory: %s",
        len(csv_files),
    )

    for csv_path in csv_files:
        logging.info("Processing existing CSV file: %s", csv_path)

        try:
            import_csv_file(config, csv_path)
            move_csv_file(csv_path, processed_directory)
            imported_file_count += 1

        except Exception:
            logging.exception(
                "Failed to import existing CSV file: %s",
                csv_path,
            )

            try:
                move_csv_file(csv_path, failed_directory)
            except Exception:
                logging.exception(
                    "Failed to move CSV file to failed directory: %s",
                    csv_path,
                )

    logging.info(
        "Existing CSV files imported: %s",
        imported_file_count,
    )

    return imported_file_count


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
    processed_directory = Path(
        get_required_config_value(config, "processedDirectory")
    )
    failed_directory = Path(
        get_required_config_value(config, "failedDirectory")
    )

    password = get_imap_password()
    test_database_connection(config)

    download_directory.mkdir(parents=True, exist_ok=True)

    import_existing_csv_files(
        config,
        download_directory,
        processed_directory,
        failed_directory,
    )

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

                    import_csv_file(config, downloaded_file)

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
