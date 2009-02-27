SET NAMES utf8;
INSERT INTO setting (name, default_value, is_enabled, subclass) VALUES
('remind_me_about_worktime', 'on', 1, NULL)
,('remind_me_about_flags', 'on', 1, NULL)
,('redirect_me_to_my_bugzilla', 'off', 1, NULL)
;
INSERT INTO setting_value (name, value, sortindex) VALUES
('remind_me_about_worktime', 'on', 5)
,('remind_me_about_worktime', 'off', 10)
,('remind_me_about_flags', 'on', 5)
,('remind_me_about_flags', 'off', 10)
,('redirect_me_to_my_bugzilla', 'off', 5)
,('redirect_me_to_my_bugzilla', 'on', 10)
;
CREATE TABLE `bugzilla`.`emailin_fields` (
`address` VARCHAR( 255 ) NOT NULL ,
`field` VARCHAR( 255 ) NOT NULL ,
`value` VARCHAR( 255 ) NOT NULL ,
PRIMARY KEY ( `address` , `field` ) 
) ENGINE = InnoDB COMMENT = 'Заданные поля для email_in.pl';
