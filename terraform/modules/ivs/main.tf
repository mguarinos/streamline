resource "aws_ivs_channel" "this" {
  name         = "${var.environment}-streamline"
  type         = "STANDARD"
  latency_mode = "LOW"
  authorized   = false

  lifecycle {
    prevent_destroy = true
  }

  # DVR — no recording_configuration_arn is needed.
  #
  # AWS IVS STANDARD channels maintain a rolling 4-hour DVR window in IVS's
  # own internal storage at no extra cost. The HLS manifest IVS serves already
  # contains the full seekable range; Video.js VHS reads it automatically.
  # Viewers can drag the timeline left to rewind up to 4 hours and click the
  # live button to snap back to the edge.
  #
  # Setting a recording_configuration_arn would enable persistent post-stream
  # storage to an S3 bucket — that is NOT what we want here. Omitting it keeps
  # DVR live-only with no S3 recording bucket required.
}

# Read back the stream key that IVS creates automatically with the channel.
data "aws_ivs_stream_key" "this" {
  channel_arn = aws_ivs_channel.this.arn
}

resource "aws_secretsmanager_secret" "stream_key" {
  name = "streamline/${var.environment}/stream-key"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "stream_key" {
  secret_id     = aws_secretsmanager_secret.stream_key.id
  secret_string = data.aws_ivs_stream_key.this.value
}
