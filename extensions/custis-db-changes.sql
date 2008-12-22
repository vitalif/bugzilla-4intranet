SET NAMES utf8;
INSERT INTO setting (name, default_value, is_enabled, subclass) VALUES
('remind_me_about_worktime', 'on', 1, NULL)
,('remind_me_about_flags', 'on', 1, NULL)
;
INSERT INTO setting_value (name, value, sortindex) VALUES
('remind_me_about_worktime', 'on', 5)
,('remind_me_about_worktime', 'off', 10)
,('remind_me_about_flags', 'on', 5)
,('remind_me_about_flags', 'off', 10)
;
