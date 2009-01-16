delimiter //

drop procedure if exists LoadMyWorktime //

create procedure LoadMyWorktime(
    IN _login_name VARCHAR(64),
    IN _pwd VARCHAR(64)
)
begin
    DROP TABLE IF EXISTS t_my_worktime;
    CREATE TEMPORARY TABLE t_my_worktime AS
    SELECT
        YEAR(l.bug_when) w_year,
        CONCAT(YEAR(l.bug_when),'-',MONTH(l.bug_when)) w_month,
        b.bug_id,
        b.short_desc,
        pr.name product,
        com.name component,
        a.name agreement,
        l.work_time
    FROM bugs b
    JOIN longdescs l ON l.who=p.userid AND b.bug_id=l.bug_id
    JOIN products pr ON pr.id=b.product_id
    JOIN components com ON com.id=b.component_id
    JOIN profiles p ON p.login_name=_login_name AND p.cryptpassword=encrypt(_pwd,p.cryptpassword)
    LEFT JOIN cf_agreement a ON a.id=b.cf_agreement;
end
//
