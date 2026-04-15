#!/usr/intel/bin/perl5.26.1 -w
# Multi-model generalization of fct_table_bu.pl
# Supports N models (auto-detected from model_tags.csv) instead of just 2.
use strict;
use warnings;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
if (!@ARGV || $ARGV[0] eq "-h" || $ARGV[0] eq "-help") {
    print "\n Multi-model FCT CSV-to-XLSX converter.\n";
    print " Usage: fct_table_multi.pl <path_to_csv_directory>\n\n";
    exit 0;
}

our $dir = $ARGV[0];

# ---------------------------------------------------------------------------
# Auto-detect number of models
# ---------------------------------------------------------------------------
# Strategy:
#   1. Try model_tags.csv for explicit "Model N (Label),path" format (future N-model runs)
#   2. Fallback: detect from data CSVs by counting consecutive rows per partition
my @model_labels;
my $n_models = 2;  # default fallback

my $detected_from_tags = 0;
if (open(my $mt_fh, '<', "$dir/model_tags.csv")) {
    my @candidate_labels;
    my $total_lines = 0;
    while (my $line = <$mt_fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        $total_lines++;
        # Match lines like "Model 1 (WW13B),/path/..." — label in parentheses
        if ($line =~ /^\s*Model\s+\d+\s+\(([^)]+)\)\s*,/) {
            push @candidate_labels, $1;
        }
    }
    close $mt_fh;
    if (@candidate_labels >= 2) {
        @model_labels = @candidate_labels;
        $n_models = scalar @model_labels;
        $detected_from_tags = 1;
    } elsif ($total_lines == 2 && !@candidate_labels) {
        # Original 2-model csv_split format (e.g., "TST:...\nREF:...")
        $n_models = 2;
        @model_labels = ("Tst", "Ref");
        $detected_from_tags = 1;
    }
}

# Fallback: detect from a data CSV (quality.csv or any available CSV)
if (!$detected_from_tags) {
    my @probe_files = qw(quality.csv ovrs.csv logs.csv vrf_normalized.csv);
    for my $probe (@probe_files) {
        my $probe_path = "$dir/$probe";
        next unless -f $probe_path;
        if (open(my $pfh, '<', $probe_path)) {
            my $header = <$pfh>;  # skip header
            my $first_tag;
            my $count = 0;
            my @tags;
            while (my $line = <$pfh>) {
                chomp $line;
                next if $line =~ /^\s*$/;
                next if index($line, ',') == -1;
                my ($tag) = split /,/, $line, 2;
                $tag =~ s/^\s+|\s+$//g;
                if (!defined $first_tag) {
                    $first_tag = $tag;
                    push @tags, $tag;
                    $count = 1;
                } elsif ($tag eq $first_tag) {
                    # Seen the first tag again — we've found the cycle length
                    last;
                } else {
                    push @tags, $tag;
                    $count++;
                }
            }
            close $pfh;
            if ($count >= 2) {
                $n_models = $count;
                @model_labels = @tags;
                last;
            }
        }
    }
}

# Ensure we have labels
if (!@model_labels) {
    @model_labels = map { "Model $_" } (1 .. $n_models);
}
while (scalar @model_labels < $n_models) {
    push @model_labels, "Model " . (scalar(@model_labels) + 1);
}

print "Detected $n_models models: " . join(", ", @model_labels) . "\n";

# ---------------------------------------------------------------------------
# Output file naming
# ---------------------------------------------------------------------------
my $corner = $dir;
$corner =~ s/.*\/([^\/]*)\/report.*/$1/;
$corner =~ s/\./_/g;
my $user = qx/whoami/;
chomp $user;
my $output_name = "$dir/indicator_table_${corner}_${user}.xlsx";

my $workbook = Excel::Writer::XLSX->new($output_name);
die "Cannot create workbook: $output_name\n" unless defined $workbook;

# ---------------------------------------------------------------------------
# Global formats
# ---------------------------------------------------------------------------
my $RedFontFormat = $workbook->add_format();
$RedFontFormat->set_bg_color('#f79999');
$RedFontFormat->set_bold();
$RedFontFormat->set_border(1);

my $GreenFontFormat = $workbook->add_format();
$GreenFontFormat->set_bg_color('#8feb9b');
$GreenFontFormat->set_bold();
$GreenFontFormat->set_border(1);

my $NeutralFontFormat = $workbook->add_format();
$NeutralFontFormat->set_bold();
$NeutralFontFormat->set_border(1);

my $PlainFormat = $workbook->add_format();
$PlainFormat->set_border(1);

my $HeaderFormat = $workbook->add_format();
$HeaderFormat->set_bold();
$HeaderFormat->set_size(8);
$HeaderFormat->set_border(1);
$HeaderFormat->set_align('vcenter');
$HeaderFormat->set_align('center');
$HeaderFormat->set_color('navy');
$HeaderFormat->set_bg_color('yellow');
$HeaderFormat->set_text_wrap();

my $DataF2 = $workbook->add_format();
$DataF2->set_text_wrap();
$DataF2->set_align('vcenter');
$DataF2->set_align('center');
$DataF2->set_size(14);
$DataF2->set_font('Courier New');
$DataF2->set_bg_color('gray');
$DataF2->set_bold();
$DataF2->set_border(1);

my $DataF = $workbook->add_format();
$DataF->set_text_wrap();
$DataF->set_align('vcenter');
$DataF->set_align('center');
$DataF->set_size(8);
$DataF->set_font('Courier New');
$DataF->set_border(1);

# ---------------------------------------------------------------------------
# Model color palette (up to 10 models)
# ---------------------------------------------------------------------------
my @palette_colors = (
    '#cad8ed',  # Model 1 - blue (same as original CurrModel)
    '#FFFFFF',  # Model 2 - white (same as original REF)
    '#f5e6cc',  # Model 3 - light peach
    '#d5e8d4',  # Model 4 - light sage
    '#e1d5e7',  # Model 5 - light lavender
    '#fff2cc',  # Model 6 - light cream
    '#dae8fc',  # Model 7 - light sky
    '#f8cecc',  # Model 8 - light pink
    '#d4edda',  # Model 9 - light mint
    '#fce5cd',  # Model 10 - light apricot
);

# Create per-model formats (normal + percent)
my @model_fmts;
my @model_fmts_pct;
for my $k (0 .. $n_models - 1) {
    my $fmt = $workbook->add_format();
    $fmt->set_border(1);
    # Model 2 (index 1) = white, don't set bg_color
    if ($k != 1) {
        $fmt->set_bg_color($palette_colors[$k % scalar @palette_colors]);
    }
    push @model_fmts, $fmt;

    my $fmt_pct = $workbook->add_format();
    $fmt_pct->set_border(1);
    $fmt_pct->set_num_format('0.00%');
    if ($k != 1) {
        $fmt_pct->set_bg_color($palette_colors[$k % scalar @palette_colors]);
    }
    push @model_fmts_pct, $fmt_pct;
}

# ---------------------------------------------------------------------------
# Tab configurations
# ---------------------------------------------------------------------------
# cond_fn returns: 'less_better', 'more_better', 'string_diff_green',
#                  'string_diff_red', 'none'

my @tabs = (
    {
        file => 'vrf_normalized.csv', name => 'vrf_norm', cnt_header => 1,
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if ($col >= 2 && $col <= 9) || ($col >= 14 && $col <= 21);
            return 'more_better';
        },
    },
    {
        file => 'unit_vrf_normalized.csv', name => 'Unit_vrf', cnt_header => 0,
        cond_fn => sub {
            my $col = shift;
            return 'less_better' if ($col >= 3 && $col <= 10) || ($col >= 16 && $col <= 23);
            return 'more_better';
        },
    },
    {
        file => 'vrf_uncompressed.csv', name => 'vrf_uncomp', cnt_header => 1,
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if ($col >= 2 && $col <= 9) || ($col >= 14 && $col <= 21);
            return 'more_better';
        },
    },
    {
        file => 'vrf_dfx.csv', name => 'vrf_dfx', cnt_header => 1,
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if ($col >= 2 && $col <= 9) || ($col >= 14 && $col <= 21);
            return 'more_better';
        },
    },
    {
        file => 'quality.csv', name => 'Quality', add_totals => 1,
        total_cols => 'C D E F G H I J K L',
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if $col >= 2 && $col <= 12;
            return 'more_better';
        },
        total_cond_fn => sub { return 'less_better'; },
    },
    {
        file => 'ovrs.csv', name => 'Ovrs', add_totals => 1,
        total_cols => 'C D E F G H I J K L',
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if $col >= 2;
            return 'none';
        },
        total_cond_fn => sub { return 'less_better'; },
    },
    {
        file => 'logs.csv', name => 'Logs', add_totals => 1,
        total_cols => 'C D E F G',
        cond_fn => sub {
            my $col = shift;
            return 'none' if $col <= 1;
            return 'less_better' if $col >= 2;
            return 'none';
        },
        total_cond_fn => sub { return 'less_better'; },
    },
    {
        file => 'tags.csv', name => 'Tags',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_green' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'ebb_summary.csv', name => 'EBB_summary',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_red' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'uarch_sum.csv', name => 'uArch_sum', pct_col => 5,
        cond_fn => sub {
            my $col = shift;
            return 'less_better'  if $col == 8 || $col == 11 || $col == 12;
            return 'more_better'  if $col == 6 || $col == 7 || $col == 9 || $col == 10 || $col == 13;
            return 'none';
        },
    },
    {
        file => 'uarch_status.csv', name => 'uArch_status', pct_col => 5,
        cond_fn => sub {
            my $col = shift;
            return 'less_better'  if $col == 8 || $col == 11 || $col == 12;
            return 'more_better'  if $col == 6 || $col == 7 || $col == 9 || $col == 10 || $col == 13;
            return 'string_diff_red' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'check_clk_latency.csv', name => 'clk_latency',
        cond_fn => sub {
            my $col = shift;
            return 'less_better' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'dops.csv', name => 'DOP_latency',
        cond_fn => sub {
            my $col = shift;
            return 'less_better' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'dop_stamping.csv', name => 'dop_stamping',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_red' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'ext_bottleneck.csv', name => 'ext_bottleneck',
        cond_fn => sub {
            my $col = shift;
            return 'less_better'     if $col == 1 || $col == 6 || $col == 7;
            return 'more_better'     if $col == 4 || $col == 5 || $col == 8;
            return 'string_diff_red' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'par_status.csv', name => 'par_status',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_green' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'model_info.csv', name => 'model_info',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_green' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'model_tags.csv', name => 'model_tags', no_alternation => 1,
        cond_fn => sub { return 'none'; },
    },
    {
        file => 'sdc_cksum.csv', name => 'sdc_cksum',
        cond_fn => sub {
            my $col = shift;
            return 'string_diff_red' if $col >= 2;
            return 'none';
        },
    },
    {
        file => 'cell_stats.csv', name => 'cell_stats',
        cond_fn => sub { return 'none'; },
    },
    {
        file => 'ports.csv', name => 'ports location',
        cond_fn => sub {
            my $col = shift;
            return 'less_better' if $col == 1;
            return 'none';
        },
    },
);

# ---------------------------------------------------------------------------
# Process all tabs
# ---------------------------------------------------------------------------
foreach my $tab (@tabs) {
    eval { process_tab(%$tab) };
    warn "Warning: Skipping $tab->{name}: $@\n" if $@;
}

$workbook->close();
print "Result is at: $output_name\n";

# ===========================================================================
# Generic tab processing subroutine
# ===========================================================================
sub process_tab {
    my (%args) = @_;
    my $file           = $args{file};
    my $name           = $args{name};
    my $cnt_header     = $args{cnt_header}     || 0;
    my $add_totals     = $args{add_totals}     || 0;
    my $total_cols_str = $args{total_cols}      || '';
    my $pct_col        = $args{pct_col};          # undef if not used
    my $cond_fn        = $args{cond_fn};
    my $total_cond_fn  = $args{total_cond_fn};
    my $no_alternation = $args{no_alternation}  || 0;

    my $filepath = "$dir/$file";
    open(my $fh, '<', $filepath) or die "Cannot open $filepath: $!\n";

    # Count lines for cnt_header tabs
    my $line_count = 0;
    if ($cnt_header) {
        $line_count++ while <$fh>;
        close $fh;
        open($fh, '<', $filepath) or die "Cannot reopen $filepath: $!\n";
    }

    # For cnt_header tabs, compute second header and skip row positions
    my ($second_header_row, $skip_row);
    if ($cnt_header) {
        $second_header_row = $line_count - ($n_models + 1);
        $skip_row          = $second_header_row - 1;
    }

    my $worksheet = $workbook->add_worksheet($name);
    $worksheet->add_write_handler(qr[\w], \&store_string_widths);

    my $delimiter = ",";
    my $x = 0;   # current row (0-indexed), only incremented for comma-containing lines
    my %label_cols;  # columns that are model/par/unit labels (no red/green)

    while (my $line = <$fh>) {
        chomp $line;

        # Only process lines containing at least one comma (matches original behavior)
        if (index($line, $delimiter) != -1) {
            my @fields = split /$delimiter/, $line;

            # On header row, detect label columns (model, par, unit, TST, etc.)
            if ($x == 0) {
                for my $ci (0 .. $#fields) {
                    my $h = lc($fields[$ci]);
                    $h =~ s/^\s+|\s+$//g;
                    $label_cols{$ci} = 1 if $h =~ /^(model|par|unit|tst|ref)$/;
                }
            }

            my $y = 0;

            # Determine if this is a header row
            my $is_header = 0;
            if ($x == 0) {
                $is_header = 1;
            } elsif ($cnt_header && defined $second_header_row && $x == $second_header_row) {
                $is_header = 1;
            }

            # For cnt_header tabs: skip the blank separator row (write nothing)
            my $is_skip_row = 0;
            if ($cnt_header && defined $skip_row && $x == $skip_row) {
                $is_skip_row = 1;
            }

            # For cnt_header tabs, determine if this row is in the totals section
            my $is_total_section = 0;
            if ($cnt_header && defined $second_header_row && $x > $second_header_row) {
                $is_total_section = 1;
            }

            # Compute model index for this data row
            my $model_idx = 0;
            if (!$is_header && !$is_skip_row && !$no_alternation) {
                if ($is_total_section) {
                    $model_idx = ($x - $second_header_row - 1) % $n_models;
                } else {
                    $model_idx = ($x - 1) % $n_models if $x > 0;
                }
            }

            if (!$is_skip_row) {
                foreach my $c (@fields) {
                    if ($is_header) {
                        $worksheet->write($x, $y, $c, $HeaderFormat);
                    } elsif ($no_alternation) {
                        $worksheet->write($x, $y, $c, $model_fmts[0]);
                    } else {
                        my $fmt;
                        if (defined $pct_col && $y == $pct_col) {
                            $fmt = $model_fmts_pct[$model_idx];
                        } else {
                            $fmt = $model_fmts[$model_idx];
                        }
                        $worksheet->write($x, $y, $c, $fmt);

                        # Conditional formatting on Model 1 row only
                        # Applied when we reach Model 2 in a group,
                        # comparing Model 1's cell to Model 2's cell
                        if ($model_idx == 1 && !$label_cols{$y}) {
                            my $cond_type = $cond_fn->($y);
                            my $model1_row = $x - 1;
                            my $model2_cell = xl_rowcol_to_cell($x, $y);

                            if ($cond_type eq 'less_better') {
                                # Model1 < LastModel = green (improved)
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '<',
                                    value => $model2_cell, format => $GreenFontFormat,
                                });
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '>',
                                    value => $model2_cell, format => $RedFontFormat,
                                });
                            } elsif ($cond_type eq 'more_better') {
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '>',
                                    value => $model2_cell, format => $GreenFontFormat,
                                });
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '<',
                                    value => $model2_cell, format => $RedFontFormat,
                                });
                            } elsif ($cond_type eq 'string_diff_green') {
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '!=',
                                    value => $model2_cell, format => $GreenFontFormat,
                                });
                            } elsif ($cond_type eq 'string_diff_red') {
                                $worksheet->conditional_formatting($model1_row, $y, {
                                    type => 'cell', criteria => '!=',
                                    value => $model2_cell, format => $RedFontFormat,
                                });
                            }
                        }
                    }
                    $y++;
                }
            }
        }

        $x++;  # Always increment to match original behavior (preserves row alignment)
    }
    close $fh;

    # -----------------------------------------------------------------------
    # Add total rows (Quality, Ovrs, Logs)
    # -----------------------------------------------------------------------
    if ($add_totals && $total_cols_str ne '') {
        my @total_col_letters = split / /, $total_cols_str;
        my $last_data_row = $x;  # $x is now one past the last written row (0-indexed)
                                 # Excel row number for last data = $x (1-indexed in formula)

        # Write N total rows
        for my $k (0 .. $n_models - 1) {
            my $total_row = $x + $k;
            $worksheet->write($total_row, 0, "Total", $model_fmts[$k]);
            $worksheet->write($total_row, 1, $model_labels[$k], $model_fmts[$k]);

            foreach my $col_letter (@total_col_letters) {
                my $col_idx = xl_col_to_name_to_col($col_letter);
                # SUMPRODUCT formula: sum values where (row-2) % n_models == k
                # Rows in Excel are 1-indexed; data starts at row 2 (0-indexed row 1)
                my $formula = sprintf(
                    '=SUMPRODUCT(%s2:%s%d,--((MOD(ROW(%s2:%s%d)-2,%d)=%d)))',
                    $col_letter, $col_letter, $last_data_row,
                    $col_letter, $col_letter, $last_data_row,
                    $n_models, $k
                );
                $worksheet->write_formula($total_row, $col_idx, $formula, $model_fmts[$k]);
            }
        }

        # Conditional formatting on Model 1 total row (compare to Model 2)
        my $model1_total_row = $x;
        my $model2_total_row = $x + 1;
        foreach my $col_letter (@total_col_letters) {
            my $col_idx = xl_col_to_name_to_col($col_letter);
            my $model2_cell = xl_rowcol_to_cell($model2_total_row, $col_idx);
            my $cond_type = $total_cond_fn ? $total_cond_fn->($col_idx) : $cond_fn->($col_idx);

            if ($cond_type eq 'less_better') {
                $worksheet->conditional_formatting($model1_total_row, $col_idx, {
                    type => 'cell', criteria => '<',
                    value => $model2_cell, format => $GreenFontFormat,
                });
                $worksheet->conditional_formatting($model1_total_row, $col_idx, {
                    type => 'cell', criteria => '>',
                    value => $model2_cell, format => $RedFontFormat,
                });
            } elsif ($cond_type eq 'more_better') {
                $worksheet->conditional_formatting($model1_total_row, $col_idx, {
                    type => 'cell', criteria => '>',
                    value => $model2_cell, format => $GreenFontFormat,
                });
                $worksheet->conditional_formatting($model1_total_row, $col_idx, {
                    type => 'cell', criteria => '<',
                    value => $model2_cell, format => $RedFontFormat,
                });
            }
        }
    }

    autofit_columns($worksheet);
}

# ===========================================================================
# Helper: convert column letter back to 0-indexed column number
# ===========================================================================
sub xl_col_to_name_to_col {
    my $name = shift;
    my $col = 0;
    for my $ch (split //, $name) {
        $col = $col * 26 + (ord(uc $ch) - ord('A') + 1);
    }
    return $col - 1;
}

# ===========================================================================
# Utility subs (unchanged from original)
# ===========================================================================
sub autofit_columns {
    my $worksheet = shift;
    my $col       = 0;
    for my $width (@{$worksheet->{__col_widths}}) {
        $worksheet->set_column($col, $col, $width) if $width;
        $col++;
    }
}

sub string_width {
    return 0.9 * length $_[0];
}

sub store_string_widths {
    my $worksheet = shift;
    my $col       = $_[1];
    my $token     = $_[2];

    return if not defined $token;
    return if $token eq '';
    return if ref $token eq 'ARRAY';
    return if $token =~ /^=/;

    # Ignore numbers
    return if $token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;

    # Ignore hyperlinks
    return if $token =~ m{^[fh]tt?ps?://};
    return if $token =~ m{^mailto:};
    return if $token =~ m{^(?:in|ex)ternal:};

    my $old_width    = $worksheet->{__col_widths}->[$col];
    my $string_width = string_width($token);

    if (not defined $old_width or $string_width > $old_width) {
        $string_width = 12 if $string_width < 12;
        $worksheet->{__col_widths}->[$col] = $string_width;
    }

    return undef;
}
