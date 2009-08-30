#!/usr/bin/perl -w

sub REQUIRED_MODULES {
    my @modules = (
    );
    return \@modules;
};

sub OPTIONAL_MODULES {
    my @modules = (
    {
        package => 'Spreadsheet-ParseExcel',
        module  => 'Spreadsheet::ParseExcel',
        version => '0.54',
        feature => 'Import of binary Excel files (*.xls)',
    },
    {
        package => 'Spreadsheet-XLSX',
        module  => 'Spreadsheet::XLSX',
        version => '0.1',
        feature => 'Import of OOXML Excel files (*.xlsx)',
    },
    );
    return \@modules;
};
