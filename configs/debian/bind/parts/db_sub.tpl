; sub [{SUBDOMAIN_NAME}] begin.
$ORIGIN {SUBDOMAIN_NAME}.
; mail rr begin.
@	IN	MX	10 {MX_HOST}
@	IN	TXT	"v=spf1 include:{DOMAIN_NAME} -all"
; mail rr ending.
@	IN	{IP_TYPE}	{DOMAIN_IP}
; sub [{SUBDOMAIN_NAME}] ending.
