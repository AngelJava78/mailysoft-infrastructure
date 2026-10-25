output "public_url" {
  value       = local.resolved_public_url
  description = "URL publica resuelta si domain_type = public; null en caso contrario."
}
