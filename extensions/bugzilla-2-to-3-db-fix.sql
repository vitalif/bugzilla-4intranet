-- SQL ������ ��������� ��������� � ����� ������ ���� �������� ��� ���������� � 2.x �� 3.�
-- ��������, ��������� �ݣ ����� ��������, �� ���� ���.
set names utf8;
-- �� ./checksetup.pl:
alter table components change wiki_url wiki_url1 varchar(255) not null;
-- ����� ./checksetup.pl:
alter table components drop wiki_url;
alter table components change wiki_url1 wiki_url varchar(255) not null;
-- ������� ������ �������� �� ����
delete from profiles_activity where userid=83;
delete from bugs_activity where attach_id=13529;
delete from bugs_activity where attach_id=13950;
delete from series_data where series_id in (647, 648, 649, 650, 651, 652, 681, 694, 695, 696, 697);
delete from category_group_map where group_id in (17, 45, 30, 23, 21, 14, 15, 27, 49, 16, 10, 18, 19, 22, 35, 31);
-- ������� ������ �������� ���������
delete from profile_setting where setting_name in ('go_to_next_bug', 'remind_me_about_worktime_newbug', 'remind_me_about_requests', 'create_bug_resolved');
-- ��������� ���������� ���� "�������" (������ ���� ��� ������� = cf_agreement)
insert into cf_agreement (value, sortkey, isactive, visibility_value_id)
    select name, sortkey, act, (case when count(`name`) > 1 then NULL else `vis` end)
    from (
        select
            (case when instr(name,' (') > 0 then substr(`name`,1,instr(name,' (')-1) else `name` end) as `name`,
            sortkey,
            1 as act,
            product_id as vis
        from agreements
        where name not in ('!��� ��������', '--', '---', '--- �����', 'Unspec')
    ) as `t0`
    group by (case when instr(name,' (') > 0 then substr(`name`,1,instr(name,' (')-1) else `name` end);
-- ������������� ���������� sortkey, �����, ����� ������������ �������� ���� ������,
create temporary table tmp1 (id int not null auto_increment primary key, sortkey int not null default 0);
insert into tmp1 (sortkey) select distinct sortkey from cf_agreement where visibility_value_id IS NOT NULL order by sortkey;
update cf_agreement set sortkey=5+5*(select tmp1.id from tmp1 where tmp1.sortkey=cf_agreement.sortkey) where visibility_value_id IS NOT NULL;
drop table tmp1;
-- � �������������� - �����
create temporary table tmp1 (id int not null auto_increment primary key, sortkey int not null default 0);
insert into tmp1 (sortkey) select distinct sortkey from cf_agreement where visibility_value_id IS NULL order by sortkey;
update cf_agreement set sortkey=200+5*(select tmp1.id from tmp1 where tmp1.sortkey=cf_agreement.sortkey) where visibility_value_id IS NULL;
drop table tmp1;
-- � --- � ����� �����
update cf_agreement set sortkey=0 where value='---';
-- ���������� �������� �������� ��� ���� �����
update bugs, agreements, cf_agreement
set bugs.cf_agreement=(case when instr(agreements.name,' (') > 0 then substr(agreements.`name`,1,instr(agreements.name,' (')-1) else agreements.`name` end)
where bugs.agreement_id=agreements.id
and agreements.name not in ('!��� ��������', '--', '---', '--- �����', 'Unspec');
