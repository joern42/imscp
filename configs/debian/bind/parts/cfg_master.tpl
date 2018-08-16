// imscp [{ZONE_NAME}] entry begin.
zone "{ZONE_NAME}" {
  type master;
  masterfile-format {BIND_DB_FORMAT};
  file "imscp/master/{DOMAIN_NAME}.db";
  allow-transfer { {IP_ADDRESSES} };
  notify yes;
};
// imscp [{ZONE_NAME}] entry ending.
