#!/bin/bash

# $1 is the session directory
SESSION_DIR="$1"

# S3 bucket
S3_BUCKET="s3://$AWS_BUCKET"

# Laravel API url
API_URL="https://api.$DOMAIN/api/create-recording"

ALL_SUCCESS=true

# Loop through all mp4 files
for RECORDING_FILE in "$SESSION_DIR"/*.mp4; do
    [ -f "$RECORDING_FILE" ] || continue

    FILE_NAME=$(basename "$RECORDING_FILE")
    ROOM_ID=$(echo "$FILE_NAME" | sed -E 's/(_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})\.mp4$//')
    NEW_NAME=$(echo "$FILE_NAME" | sed -E 's/.*_([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})\.mp4$/\1/').mp4

    # Upload to S3
    echo "Uploading $FILE_NAME to $S3_BUCKET..."
    aws s3 cp "$RECORDING_FILE" "$S3_BUCKET/$NEW_NAME" --storage-class STANDARD
    if [ $? -ne 0 ]; then
        echo "S3 upload failed for $FILE_NAME, keeping local file."
        ALL_SUCCESS=false
        continue
    fi

    # Construct S3 URL
    S3_URL="https://$AWS_BUCKET.s3.$AWS_DEFAULT_REGION.amazonaws.com/$NEW_NAME"

    # Post to Laravel API
    echo "Posting $FILE_NAME to Laravel..."
    RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" -u "$API_USER:$API_PASS" \
        -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Origin: https://oritelemed.com.br" \
        -H "Referer: https://oritelemed.com.br" \
        -H "User-Agent: Mozilla/5.0" \
        -d "{
              \"room_id\": \"$ROOM_ID\",
              \"s3_key\": \"$NEW_NAME\",
              \"s3_url\": \"$S3_URL\",
              \"file_name\": \"$NEW_NAME\",
              \"recorded_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
            }")

    if [ "$RESPONSE" -eq 200 ] || [ "$RESPONSE" -eq 201 ]; then
        echo "Laravel push successful, deleting local file $FILE_NAME..."
        rm -f "$RECORDING_FILE"
    else
        echo "Laravel push failed (HTTP $RESPONSE), keeping local file $FILE_NAME."
        ALL_SUCCESS=false
    fi
done

# If all files were successfully uploaded and pushed, remove the directory
if [ "$ALL_SUCCESS" = true ]; then
    echo "All files processed successfully. Removing session directory $SESSION_DIR..."
    rm -rf "$SESSION_DIR"
else
    echo "Some files failed. Session directory $SESSION_DIR is kept for retry."
fi

