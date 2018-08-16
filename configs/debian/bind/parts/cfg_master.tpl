// imscp [{ZONE_NAME}] begin.
zone "{ZONE_NAME}" {
  type master;
  masterfile-format {BIND_DB_FORMAT};
  file "imscp/master/{ZONE_NAME}.db";
  allow-transfer { {IP_ADDRESSES} };
  notify yes;
};
// imscp [{ZONE_NAME}] ending.

