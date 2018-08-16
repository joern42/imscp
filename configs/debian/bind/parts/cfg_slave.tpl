// imscp [{ZONE_NAME}] entry begin.
zone "{ZONE_NAME}" {
  type slave;
  masterfile-format {BIND_DB_FORMAT};
  file "imscp/slave/{DOMAIN_NAME}.db";
  masters { {IP_ADDRESSES} };
};
// imscp [{ZONE_NAME}] entry ending.
