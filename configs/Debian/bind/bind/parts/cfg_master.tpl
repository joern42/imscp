zone "{DOMAIN_NAME}" {
    type master;
    masterfile-format {NAMED_DB_FORMAT};
    file "imscp/master/{DOMAIN_NAME}.db";
    allow-transfer {
        {NAMED_SECONDARY_DNS}
    };
    notify yes;
};
