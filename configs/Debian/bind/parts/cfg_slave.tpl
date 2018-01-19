zone "{DOMAIN_NAME}" {
  type slave;
  masterfile-format {NAMED_DB_FORMAT};
  file "imscp/slave/{DOMAIN_NAME}.db";
  masters { {NAMED_PRIMARY_DNS} };
};
