#!/bin/bash
#$ -S /bin/bash

# Prerequisits:
# (1) This pipeline is developed by Java with version 7

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Need to change ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#========== software required ==========
tipseqjar="/java/TIPseqHunter.jar"

#========== database files ==========
eurefpath="/euL1db"
euref="euL1db_hg19_ReferenceL1HS_20151222.simple.noheader.bed"
eumrippath="/euL1db"
eumrip="euL1db_hg19_MRIP_20151222.simple.noheader.bed"
refseqpath="/refseq_gft"
refseq="refFlat-20160208.txt"

# Hardcoded for now
thresh_pred=0.5 # the threshold of predicted probability for qualified somatic insertion (0.0-1.0) (0, 0.5)
thresh_polya=0.7 # the threshold of "A" or "T" percentage of polyA tail (last 11 bps) for qualified somatic insertion (0.7)
thresh_varitidx=4.0 # the threshold of variant index of target region for qualified somatic insertion (4.0, 5.0)
thresh_NvsT=0.05 # the threshold of percentage (percentage = the total counts of normal / the total counts of tumor) (0.03, 0.05)
thresh_promoter=1000 # the region to be considered as promoter from TSS and TES
if_header_list=T
l1hsprimer_end_noA="AGATATACCTAATGCTAGATGACACGTTAGTGGGTGCAGCGCACCAGCATGGCACATGTATACATATGTAACTAACCTGCACAATGTGCACATGTACCCTAAAACTTAGAGTATAAT"
l1hsprimer_end_noA_rc="ATTATACTCTAAGTTTTAGGGTACATGTGCACATTGTGCAGGTTAGTTACATATGTATACATGTGCCATGCTGGTGCGCTGCACCCACTAACGTGTCATCTAGCATTAGGTATATCT"
l1hsprimer="a(5904)"

# input parameters
repred_path=${OUTPUT_DIR:?}/model # the file ending with ".repred" and generated from P11 in "model" folder
control_path=${OUTPUT_DIR:?}/TRLocator # this path should be the "TRLocator" folder output from previous shell script
repred_file=${REPRED_FILE:?} # input file (predicted result from TIPseqHunter pipeline) (Note*****: file name should be ending with ".repred".) (such as 302_T_GTCCGC.wsize100.regwsize1.minreads1.clip1.clipflk5.mindis150.FP.uniqgs.bed.csinfo.lm.l1hs.pred.txt.repred)
control_file=${MINTAG_FILE:?} # this file should be the normal tissue file in the TRLocator (Note*****: file name should be ending with ".w100.minreg1.mintag1.bed".) (such as 302_N_GTGAAA.fastq.cleaned.fastq.pcsort.bam.w100.minreg1.mintag1.bed)

echo "repred-path="$repred_path
echo "repred-file="$repred_file
echo "control-path="$control_path
echo "control-file="$control_file

########## first-step: annotate each insertion with euL1db annotation files #############
# P6_IdentificationOfExistingMobileDNASite.java
bed1flk=100 # number of flanking base pairs on each side for overlapping regions
bed1chr=4 # column number of chormosome (starting from 0) on first bed file
bed1s=5 # column number of target start position (starting from 0) on first bed file
bed1e=6 # column number of target end position (starting from 0) on first bed file
bed2chr=0 # column number of chromosome (starting from 0) on second bed file
bed2s=1 # column number of target start position (starting from 0) on second bed file
bed2e=2 # column number of target end position (starting from 0) on second bed file
bed2add1=0 # column number of additional information shown on the new output file (starting from 0) on second bed file
bed2add2=1 # column number of additional information shown on the new output file (starting from 0) on second bed file
bed2add3=2 # column number of additional information shown on the new output file (starting from 0) on second bed file
outnamekey1=EuRef.bed # key information for the output file name (such as FP stands for fixed-present annotation)
outnamekey2=EuMRIP.bed # key information for the output file name (such as FP stands for fixed-present annotation)
ifheader=TRUE # if both bed files have header or not
java $JFLAGS -classpath ${tipseqjar} org/nyumc/TIPseqHunter_20150727/P6_IdentificationOfExistingMobileDNASite ${repred_path} ${eurefpath} ${repred_file} ${euref} ${bed1flk} ${bed1chr} ${bed1s} ${bed1e} ${bed2chr} ${bed2s} ${bed2e} ${bed2add1} ${bed2add2} ${bed2add3} ${outnamekey1} ${ifheader}
feature_mrip=${repred_file}.${outnamekey1}
java $JFLAGS -classpath ${tipseqjar} org/nyumc/TIPseqHunter_20150727/P6_IdentificationOfExistingMobileDNASite ${repred_path} ${eumrippath} ${feature_mrip} ${eumrip} ${bed1flk} ${bed1chr} ${bed1s} ${bed1e} ${bed2chr} ${bed2s} ${bed2e} ${bed2add1} ${bed2add2} ${bed2add3} ${outnamekey2} ${ifheader}

########## second-step: compare each insertion with control sites #############
bed1flk=50
bed1chr=4
bed1s=5
bed1e=6
bed2chr=0
bed2s=1
bed2e=2
bed2add1=3
bed2add2=4
outnamekey3=N.bed
ifheader1=TRUE
ifheader2=FALSE
feature_pp1=${feature_mrip/%.bed/}
feature_pp1=${feature_pp1}.${outnamekey2}
java $JFLAGS -classpath ${tipseqjar} org/nyumc/TIPseqHunter_20150727/PP1_FindMatchInControl ${repred_path} ${control_path} ${feature_pp1} ${control_file} $bed1flk $bed1chr $bed1s $bed1e $bed2chr $bed2s $bed2e $bed2add1 $bed2add2 $outnamekey3 $ifheader1 $ifheader2

########## third-step: select somatic insertions #############
feature_pp2=${feature_pp1/%.bed/}
feature_pp2=${feature_pp2}.${outnamekey3}
java $JFLAGS -classpath ${tipseqjar} org/nyumc/TIPseqHunter_20150727/PP2_SelectionOfTumorSpecificInsertion ${repred_path} ${feature_pp2} ${thresh_pred} ${thresh_polya} ${thresh_varitidx} ${thresh_NvsT} ${l1hsprimer_end_noA} ${l1hsprimer_end_noA_rc} ${l1hsprimer}

########## fourth-step: annotate selected insertions #############
int_pred=`awk "BEGIN {printf \"%.0f\n\", $thresh_pred*100}"`
int_polya=`awk "BEGIN {printf \"%.0f\n\", $thresh_polya*100}"`
int_varitidx=`awk "BEGIN {printf \"%.0f\n\", $thresh_varitidx}"`
int_NvsT=`awk "BEGIN {printf \"%.0f\n\", $thresh_NvsT*100}"`
selected_file=${feature_pp2}.p${int_pred}at${int_polya}vi${int_varitidx}nt${int_NvsT}.selected
java $JFLAGS -classpath ${tipseqjar} org/nyumc/TIPseqHunter_20150727/P15_AnnotateOutputUsingRefseqFile ${refseqpath} ${repred_path} ${refseq} ${selected_file} ${thresh_promoter} ${if_header_list}
