// imscp [{ZONE_NAME}] begin.
zone "{ZONE_NAME}" {
  type slave;
  masterfile-format {BIND_DB_FORMAT};
  file "imscp/slave/{ZONE_NAME}.db";
  masters { {IP_ADDRESSES} };
};
// imscp [{ZONE_NAME}] ending.

