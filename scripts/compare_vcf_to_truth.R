#!/usr/bin/env Rscript

## Script to compare VCF output to bespoke array genotypes
## Could be generalized

args <- commandArgs(trailingOnly = FALSE)
for(key in c("--file=", "--f=")) {
    i <- substr(args, 1, nchar(key)) == key
    if (sum(i) == 1) {
        script_dir <- dirname(substr(args[i], nchar(key) + 1, 1000))
        setwd(file.path(script_dir, "../"))
    }
}
Sys.setenv(PATH = paste0(getwd(), ":", Sys.getenv("PATH")))

source("scripts/compare_vcf_to_truth_functions.R")
source("STITCH/R/functions.R") ## for function generate_hwe_on_counts

library("data.table")
library("optparse")

option_list <- list(
    make_option(
        "--vcf",
        type = "character",
        help = "VCF output"
    ),
    make_option(
        "--truth-vcf",
        type = "character",
        help = "VCF output",
        default = NA
    ),
    make_option(
        "--chr",
        type = "character",
        help = "chr",
        default = NA
    ),
    make_option(
        "--compare-against",
        type = "character",
        help = "Compare against either affy, megamuga, or truth_vcf",
        dest = "compare_against",
        default = "nothing"
    ),
    make_option(
        "--verbose",
        action = "store_true",
        default = FALSE
    ),
    make_option(
        "--mega-save-file",
        type = "character",        
        help = "RData file to save mega-muga processed results",
        dest = "mega_save_file",
        default = NA
    ),
    make_option(
        "--cfw-data-dir",
        type = "character",        
        help = "Where CFW truth files are stored",
        dest = "cfw_data_dir",
        default = "/data/smew1/rdavies/stitch_development/truth/cfw/"
    )
)

opt <- suppressWarnings(parse_args(OptionParser(option_list = option_list)))

## vcf_file <- "/data/smew1/rdavies/stitch_development/STITCH_github_latest/STITCH/test-results/whole_chr_CFW_1.3.5/stitch.chr19.vcf.gz"; chr <- "chr19"; compare_against <- "megamuga"; verbose = TRUE
vcf_file <- opt$vcf
truth_vcf_file <- opt$truth_vcf
chr <- opt$chr
compare_against <- opt$compare_against
verbose <- opt$verbose
mega_save_file <- opt$mega_save_file
cfw_data_dir <- opt$cfw_data_dir
megamugadir <- file.path(cfw_data_dir, "megamuga")
affydir <- file.path(cfw_data_dir, "affy")




if (is.na(chr))
    stop("specify chr")

if (compare_against == "affy") {

    message("--- Compare Affymetrix to Input VCF ---")
    affy_calls <- get_affymetrix_calls_for_chr(chr)
    affy_calls <- filter_calls_for_chr(affy_calls)
    subjects <- colnames(affy_calls)[grep("Q_", colnames(affy_calls))]
    out <- get_dosages_for_vcf(vcf_file, chr, subjects, affy_calls)
    dosages <- out$dosages
    dosages_meta <- out$dosages_meta
    compare_array_calls_and_dosages(affy_calls, dosages, dosages_meta)

} else if (compare_against == "megamuga") {

    message("--- Compare MegaMUGA to Input VCF ---")
    if (is.na(mega_save_file) | file.exists(mega_save_file) == FALSE) {
        megamuga <- get_megamuga_calls_for_chr(chr)
        mega_calls <- convert_megamuga_to_calls(megamuga, chr)
        mega_calls <- filter_calls_for_chr(mega_calls)
        subjects <- colnames(mega_calls)[grep("Q_", colnames(mega_calls))]
        if (is.na(mega_save_file) == FALSE) {
            save(mega_calls, subjects, file = mega_save_file)
        }
    } else {
        message("Load previous MegaMuga file")
        load(mega_save_file)
    }
    out <- get_dosages_for_vcf(vcf_file, chr, subjects, mega_calls)
    dosages <- out$dosages
    dosages_meta <- out$dosages_meta
    compare_array_calls_and_dosages(mega_calls, dosages, dosages_meta)

} else if (compare_against == "truth_vcf") {

    message("--- Compare Truth VCF to Input VCF ---")
    out <- get_dosages_for_vcf(truth_vcf_file, chr, subjects = NULL, calls = NULL, use_fread = FALSE, tabix = FALSE)
    truth_dosages <- out$dosages
    out <- get_dosages_for_vcf(vcf_file, chr, subjects = NULL, calls = NULL, use_fread = FALSE, tabix = FALSE)
    dosages <- out$dosages

} else {

    stop("incorrect choice of comparison")

}

