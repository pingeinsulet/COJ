resource "aws_route53_record" "nonprod_this" {
  count   = var.route53_zone_id != "" && var.route53_alias_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.route53_alias_name
  type    = "A"

  alias {
    name                   = aws_lb.nonprod_alb.dns_name
    zone_id                = aws_lb.nonprod_alb.zone_id
    evaluate_target_health = true
  }
}