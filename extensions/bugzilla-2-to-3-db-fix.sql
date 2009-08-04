-- SQL ������ ��������� ��������� � ����� ������ ���� �������� ��� ���������� � 2.x �� 3.�
-- ��������, ��������� �ݣ ����� ��������, �� ���� ���.
set names utf8;
-- ������� ������ �������� �� ����
delete from profiles_activity where userid=83;
delete from bugs_activity where attach_id=13529;
delete from bugs_activity where attach_id=13950;
delete from series_data where series_id in (647, 648, 649, 650, 651, 652, 681, 694, 695, 696, 697);
delete from category_group_map where group_id in (17, 45, 30, 23, 21, 14, 15, 27, 49, 16, 10, 18, 19, 22, 35, 31);
-- ������� ������ �������� ���������
delete from profile_setting where setting_name in ('go_to_next_bug', 'remind_me_about_worktime_newbug', 'remind_me_about_requests', 'create_bug_resolved');
-- ��������� ���������� ���� "�������" (������ ���� ��� ������� = cf_agreement)
insert into cf_agreement (value, sortkey, isactive)
    select name, sortkey, 1
    from `agreements`
    where name not in ('!��� ��������', '--', '---', '--- �����')
    group by name
    order by name;
-- ���������� �������� �������� ��� ���� �����
update bugs, agreements, cf_agreement set bugs.cf_agreement=agreements.name where bugs.agreement_id=agreements.id and agreements.name not in ('!��� ��������', '--', '---', '--- �����');
