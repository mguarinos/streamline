output "playback_url" {
  description = "Full IVS playback URL (master.m3u8)"
  value       = aws_ivs_channel.this.playback_url
}

output "ingest_endpoint" {
  description = "RTMP ingest URL — paste into OBS/Larix as Server"
  value       = aws_ivs_channel.this.ingest_endpoint
}

output "channel_arn" {
  description = "IVS channel ARN — used by Lambda to call GetStream"
  value       = aws_ivs_channel.this.arn
}

output "stream_key_arn" {
  description = "Secrets Manager secret ARN storing the IVS stream key"
  value       = aws_secretsmanager_secret.stream_key.arn
}
