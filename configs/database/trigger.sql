delimiter //

DROP TRIGGER IF EXISTS updateResellerAssigmentsOnClientPropsInsert //
CREATE TRIGGER updateResellerAssigmentsOnClientPropsInsert
  AFTER INSERT
  ON imscp_client_props
  FOR EACH ROW
  BEGIN
    UPDATE imscp_reseller_props AS t1
      JOIN imscp_user AS t2 ON (t2.userID = NEW.userID)
    SET t1.domainsAssigned      = IF(NEW.domainsLimit <> '-1', t1.domainsAssigned + NEW.domainsLimit, t1.domainsAssigned),
      t1.subdomainsAssigned     = IF(NEW.subdomainsLimit <> '-1', t1.subdomainsAssigned + NEW.subdomainsLimit, t1.subdomainsAssigned),
      t1.mailaccountsAssigned   = IF(NEW.mailboxesLimit <> '-1', t1.mailaccountsAssigned + NEW.mailboxesLimit, t1.mailaccountsAssigned),
      t1.ftpUsersAssigned    = IF(NEW.ftpUsersLimit <> '-1', t1.ftpUsersAssigned + NEW.ftpUsersLimit, t1.ftpUsersAssigned),
      t1.sqlDatabasesAssigned   = IF(NEW.sqlDatabasesLimit <> '-1', t1.sqlDatabasesAssigned + NEW.sqlDatabasesLimit, t1.sqlDatabasesAssigned),
      t1.sqlUsersAssigned       = IF(NEW.sqlUsersLimit <> '-1', t1.sqlUsersAssigned + NEW.sqlUsersLimit, t1.sqlUsersAssigned),
      t1.diskspaceAssigned      = IF(NEW.diskspaceLimit <> '-1', t1.diskspaceAssigned + NEW.diskspaceLimit, t1.diskspaceAssigned),
      t1.monthlyTrafficAssigned = IF(NEW.monthlyTrafficLimit <> '-1', t1.monthlyTrafficAssigned + NEW.monthlyTrafficLimit,
                                     t1.monthlyTrafficAssigned)
    WHERE t1.userID = t2.createdBy;
  END //

DROP TRIGGER IF EXISTS updateResellerAssigmentsOnClientPropsUpdate //
CREATE TRIGGER updateResellerAssigmentsOnClientPropsUpdate
  AFTER UPDATE
  ON imscp_client_props
  FOR EACH ROW
  BEGIN
    IF NEW.domainsLimit <> OLD.domainsLimit OR NEW.subdomainsLimit <> OLD.subdomainsLimit OR NEW.mailboxesLimit <> OLD.mailboxesLimit
       OR NEW.ftpUsersLimit <> OLD.ftpUsersLimit OR NEW.sqlDatabasesLimit <> OLD.sqlDatabasesLimit OR NEW.sqlUsersLimit <> OLD.sqlUsersLimit
       OR NEW.diskspaceLimit <> OLD.diskspaceLimit OR NEW.monthlyTrafficLimit <> OLD.monthlyTrafficLimit
    THEN
      UPDATE imscp_reseller_props AS t1
        JOIN imscp_user AS t2 ON (t2.userID = NEW.userID)
      SET t1.domainsAssigned      = IF(NEW.domainsLimit <> '-1', t1.domainsAssigned + NEW.domainsLimit, t1.domainsAssigned),
        t1.subdomainsAssigned     = IF(NEW.subdomainsLimit <> '-1', t1.subdomainsAssigned + NEW.subdomainsLimit, t1.subdomainsAssigned),
        t1.mailaccountsAssigned   = IF(NEW.mailboxesLimit <> '-1', t1.mailaccountsAssigned + NEW.mailboxesLimit, t1.mailaccountsAssigned),
        t1.ftpUsersAssigned    = IF(NEW.ftpUsersLimit <> '-1', t1.ftpUsersAssigned + NEW.ftpUsersLimit, t1.ftpUsersAssigned),
        t1.sqlDatabasesAssigned   = IF(NEW.sqlDatabasesLimit <> '-1', t1.sqlDatabasesAssigned + NEW.sqlDatabasesLimit, t1.sqlDatabasesAssigned),
        t1.sqlUsersAssigned       = IF(NEW.sqlUsersLimit <> '-1', t1.sqlUsersAssigned + NEW.sqlUsersLimit, t1.sqlUsersAssigned),
        t1.diskspaceAssigned      = IF(NEW.diskspaceLimit <> '-1', t1.diskspaceAssigned + NEW.diskspaceLimit, t1.diskspaceAssigned),
        t1.monthlyTrafficAssigned = IF(NEW.monthlyTrafficLimit <> '-1', t1.monthlyTrafficAssigned + NEW.monthlyTrafficLimit,
                                       t1.monthlyTrafficAssigned)
      WHERE t1.userID = t2.createdBy;
    END IF;
  END //

delimiter ;
