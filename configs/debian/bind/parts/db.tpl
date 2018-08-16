$TTL 3H
$ORIGIN {DOMAIN_NAME}.
@	IN	SOA	{NS_NAME}. {HOSTMASTER_EMAIL}. (
	{TIMESTAMP}; Serial
	3H; Refresh
	1H; Retry
	2W; Expire
	1H; Minimum TTL
)
; ns rr begin.
@		IN	NS	{NS_NAME}
; ns rr ending.
; glue rr begin.
{NS_NAME}	IN	{NS_IP_TYPE}	{NS_IP}
; glue rr ending.
; mail rr begin.
@		IN	MX	10	{MX_HOST}
@		IN	TXT	"v=spf1 mx -all"
; mail rr ending.
@		IN	{IP_TYPE}	{DOMAIN_IP}
www		IN	CNAME	@
; sub [{SUBDOMAIN_NAME}] begin.
; sub [{SUBDOMAIN_NAME}] ending.
$ORIGIN {DOMAIN_NAME}.
; dns rr begin.
; dns rr ending.
