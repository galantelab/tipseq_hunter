#!/bin/bash
#$ -S /bin/bash

# Created: July-19-2017
# TIPseqHunter2: imprvoed version of TIPseqHunter (Tang PNAS 2017)

# Prerequisits:
# (1) This pipeline is developed by Java with version 1.7 (with at least 10G memory available)
# (2) Bowtie 2 alignment software (version 2.2.3 used for testing) [http://bowtie-bio.sourceforge.net/bowtie2/index.shtml]
# (3) Samtools software (latest version) [http://samtools.sourceforge.net/]
# (4) Trimmomatic software (version 0.32 used for testing) [http://www.usadellab.org/cms/?page=trimmomatic]
# (4) Java packages needed: sam-1.112.jar, commons-math3-3.4.1.jar, jfreechart-1.0.14.jar, jcommon-1.0.17.jar, itextpdf-5.2.1.jar, biojava3-core-3.0.1.jar
# (5) R and its packages needed: pROC, ggplot2, caret, e1071
# (6) BAM file has to be bowtie2 alignment with "XM" tag

#========== software required ==========
tipseqjar="/java/TIPseqHunter2.jar"
trimmomaticpath="/java/Trimmomatic-0.32"
bowtie2path="/bowtie2-2.2.3" 
picardpath="/java/picard-tools-1.79"
samjarpath="/java/picard-tools-1.112/sam-1.112.jar"
mathjarpath="/java/commons-math3-3.4.1/commons-math3-3.4.1.jar"
jfjarpath="/java/jfreechart-1.0.14/jfreechart-1.0.14.jar"
jcommonpath="/java/jcommon-1.0.17.jar"
jtextpath="/java/itextpdf-5.2.1.jar"
biojavapath="/java//biojava3-core-3.0.1.jar"

#========== database files ==========
test ${hg19_refindex:?}
test ${hg19_fai:?}
test ${l1hs_refindex:?}
test ${l1hs_fai:?}
test ${adapterfa:?}
test ${positive_anno_path:?}
test ${positive_anno_file:?}
test ${pathezm:?}
test ${ezm:?}
test ${l1hsseq:?}

# input parameters
fastq_path=$1 # path for the fastq files (Note: this is the only path and file name is not included)
output_folder=$2 # path for the output files (Note: this is the only path and file name is not included)
fastq_r1=$3 # read 1 file name of paired fastq files
key_r1=$4 # key word to recognize read 1 of fastq file (such as "_1" is the key word for CAGATC_1.fastq fastq file) (Note*****: key has to be unique in the file name)
key_r2=$5 # key word to recognize read 2 of fastq file (such as "_2" is the key word for CAGATC_2.fastq fastq file) (Note*****: key has to be unique in the file name)
readnum=$6 # the total number of the read pairs on one of the paired fastq files (read1 or read2)
fastq_r2=${fastq_r1//$key_r1/$key_r2}

echo "input-fastq-folder="$fastq_path
echo "output-folder="$output_folder
echo "fastq-read1="$fastq_r1
echo "fastq-read2="$fastq_r2
echo "total-number-of-reads-in-one-fastq="$readnum

# for Bowtie2 alignment
Xvalue=1000 # please reference to bowtie software
nslots=8 # number of cpus for alignment
# for P4
wsize=100 # (base pair for peak identification) two neighbour peaks will be merged together if the distance between two peaks is less than window size 
regwsize=1 # minimum width of peak (base pair)
minreads=1 # minimum number of reads within peak (count)
# for P5
clip=1 # minimum number of supporting clipped reads
clipflk=5 # number of flanking base pairs on each side based on qualified clipping position selected
mindis=150 # minimum distance of clipping position to the both ends of peak (not using now)
# for P6
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
outnamekey1=l1ta.bed # key information for the output file name (such as FP stands for fixed-present annotation, which is 200-l1hs-ta from both repeatmasker and dbrip, rmsk for 1544-l1hs from repeatmasker, rmskta for 464-l1hs-ta from repeatmasker)
ifheader=FALSE # if both bed files have header or not
# for P7
sc=3 # column number of supporting clipped reads
gs=16 # column number of positive instance annotation
outnamekey2=uniqgs.bed # key information for the output file name (such as uniqgs stands for unique gold standarded)
ifheader=FALSE # if the file has header
# for P8
dis=5000 # the maximum region calculated for average coverage of enzyme cutting sites. output file is a pdf file
# for p10
thresh_mismatch=5 # the maximum number of mismatches that are considered to be qualified alignment when decide the position of the most 5'-end of L1Hs-primer
preferred_mismatch=2 # if cannot find l1hskey, how many mismatch threshold you preferred
# discarded: top_n=1 # the top n position with sharpest changes in the L1Hs-reference alignments
# for P11
l1hskey='a(5904)' # information of nucleiotide and L1Hs reference genome location for L1Hs primer

# generate path for output information
algn_hs_path=$output_folder/bowtie_human # path for human alignment (Note: this is the only path and file name is not included)
algn_te_path=$output_folder/bowtie_l1hs # path for L1Hs aligned (Note: this is the only path and file name is not included)
trlocator_path=$output_folder/TRLocator # path for the target region idenfication (Note: this is the only path and file name is not included)
feature_path=$output_folder/features # path for the feature generation (Note: this is the only path and file name is not included)
model_path=$output_folder/model # path for the model building and prediction (Note: this is the only path and file name is not included)

if [ -d "$algn_hs_path" ]; then
	echo "$algn_hs_path exists and we are removing the existing folder."
	# rm -rf $algn_hs_path
else
	echo "Creating new folder: $algn_hs_path"
	mkdir $algn_hs_path
fi

if [ -d "$algn_te_path" ]; then
	echo "$algn_te_path exists and we are removing the existing folder."
	# rm -rf $algn_te_path
else
	echo "Creating new folder: $algn_te_path"
	mkdir $algn_te_path
fi

if [ -d "$trlocator_path" ]; then
	echo "$trlocator_path exists and we are removing the existing folder."
	# rm -rf $trlocator_path
else
	echo "Creating new folder: $trlocator_path"
	mkdir $trlocator_path
fi

if [ -d "$feature_path" ]; then
	echo "$feature_path exists and we are removing the existing folder."
	# rm -rf $feature_path
else
	echo "Creating new folder: $feature_path"
	mkdir $feature_path
fi

if [ -d "$model_path" ]; then
	echo "$model_path exists and we are removing the existing folder."
	# rm -rf $model_path
else
	echo "Creating new folder: $model_path"
	mkdir $model_path
fi

########## first-step: preparation (quality control and alignment) #############

# parameters for preparation:
cleaned_fq1=${fastq_r1}.cleaned.fastq
cleaned_fq2=${fastq_r2}.cleaned.fastq
outrmfq1=${fastq_r1}.removed.fastq
outrmfq2=${fastq_r2}.removed.fastq
logfile=${fastq_r1}.log
outsam=${cleaned_fq1/$key_r1/}.sam
outbam=${outsam/%.sam/.bam}
outsortbam=${outbam/%.bam/.pcsort.bam}
outnamesortbamfilepre=${outsortbam/%.bam/.qyname}
outnamesortbamfile=${outsortbam/%.bam/.qyname.bam}

# quality control (using Trimmomatic)
java -jar ${trimmomaticpath}/trimmomatic-0.32.jar PE -threads $nslots -phred33 -trimlog ${fastq_path}/${logfile} ${fastq_path}/${fastq_r1} ${fastq_path}/${fastq_r2} ${fastq_path}/${cleaned_fq1} ${fastq_path}/${outrmfq1} ${fastq_path}/${cleaned_fq2} ${fastq_path}/${outrmfq2} ILLUMINACLIP:${adapterfa}:3:30:7:1:TRUE LEADING:2 TRAILING:2 SLIDINGWINDOW:4:10 MINLEN:36

# bowtie alignment to hg19
${bowtie2path}/bowtie2 -X $Xvalue --local --phred33 --sensitive -p $nslots -x ${hg19_refindex} -1 ${fastq_path}/${cleaned_fq1} -2 ${fastq_path}/${cleaned_fq2} -S ${algn_hs_path}/${outsam}
# sam to bam using samtools
samtools view -b -S -t $hg19_fai -o ${algn_hs_path}/${outbam} ${algn_hs_path}/${outsam}
# sort bam file based on coordinates using picard
java -jar ${picardpath}/SortSam.jar SO=coordinate VALIDATION_STRINGENCY=SILENT MAX_RECORDS_IN_RAM=500000 I=${algn_hs_path}/${outbam} O=${algn_hs_path}/${outsortbam}
# index sorted bam file using picard
java -jar ${picardpath}/BuildBamIndex.jar VALIDATION_STRINGENCY=SILENT MAX_RECORDS_IN_RAM=500000 INPUT=${algn_hs_path}/${outsortbam} OUTPUT=${algn_hs_path}/${outsortbam}.bai
# sort bam file based on query name
samtools sort -n ${algn_hs_path}/${outsortbam} ${algn_hs_path}/${outnamesortbamfilepre}

# bowtie alignment to L1Hs
${bowtie2path}/bowtie2 -X $Xvalue --local --phred33 --sensitive -p $nslots -x ${l1hs_refindex} -1 ${fastq_path}/${cleaned_fq1} -2 ${fastq_path}/${cleaned_fq2} -S ${algn_te_path}/${outsam}
# sam to bam using samtools
samtools view -b -S -t ${l1hs_fai} -o ${algn_te_path}/${outbam} ${algn_te_path}/${outsam}
# sort bam file based on coordinates using picard
java -jar ${picardpath}/SortSam.jar SO=coordinate VALIDATION_STRINGENCY=SILENT MAX_RECORDS_IN_RAM=500000 I=${algn_te_path}/${outbam} O=${algn_te_path}/${outsortbam}
# index sorted bam file using picard
java -jar ${picardpath}/BuildBamIndex.jar VALIDATION_STRINGENCY=SILENT MAX_RECORDS_IN_RAM=500000 INPUT=${algn_te_path}/${outsortbam} OUTPUT=${algn_te_path}/${outsortbam}.bai
# sort bam file based on query name
samtools sort -n ${algn_te_path}/${outsortbam} ${algn_te_path}/${outnamesortbamfilepre}

########## second-step: feature calculation for model #############

# P1_ParsingMobileDNAAlignmentFileBowtie2.java (using l1hs aligned query-name-sorted bam file)
java -Xmx50g -classpath ${tipseqjar}:${samjarpath} org/nyumc/TIPseqHunter2_20170616/P1_ParsingMobileDNAAlignmentFileBowtie2 ${algn_te_path} ${outnamesortbamfile}

# P2_TRLocator_TargetRegionIdentification.java (using hg19 aligned coordinate-sorted bam file)
java -Xmx50g -classpath ${tipseqjar}:${samjarpath} org/nyumc/TIPseqHunter2_20170616/P2_TRLocator_TargetRegionIdentification ${algn_hs_path} ${trlocator_path} ${outsortbam} ${wsize} ${regwsize} ${minreads}

# P3_ExtractInfoFromWGAlignmentUsingP1IDListWithGGAligned_v2.java (using P1 parsed bed file and hg19 aligned query-name-sorted bam file)
l1hs_id=${outnamesortbamfile}.1Map2Mis.pairs.ids.only
regfile=${outsortbam}.w${wsize}.minreg${regwsize}.mintag${minreads}.bed
java -Xmx50g -classpath ${tipseqjar}:${samjarpath} org/nyumc/TIPseqHunter2_20170616/P3_ExtractInfoFromWGAlignmentUsingP1IDListWithGGAligned_v2 ${algn_te_path} ${l1hs_id} ${algn_hs_path} ${outnamesortbamfile} ${trlocator_path} ${regfile}

# P4_ExtractPolyATInfo_v2.java (using P2 output file and hg19 aligned coordinate-sorted bam file
pos=${outnamesortbamfile}.L1HSAligned.sc.leftvsright.bed
java -Xmx50g -classpath ${tipseqjar}:${samjarpath} org/nyumc/TIPseqHunter2_20170616/P4_ExtractPolyATInfo_v2 ${algn_hs_path} ${algn_hs_path} $pos ${outsortbam}

# P5_CandidateInsertionSiteIdentification_v2.java (using target file from P4 and clipping file from P3)
clipfile=${outnamesortbamfile}.L1HSAligned.sc.leftvsright.bed.consensusbp
java -classpath ${tipseqjar} org/nyumc/TIPseqHunter2_20170616/P5_CandidateInsertionSiteIdentification_v2 ${trlocator_path} ${algn_hs_path} ${regfile} ${clipfile} ${wsize} ${regwsize} ${minreads} ${clip} ${clipflk} ${mindis}

# P6_IdentificationOfExistingMobileDNASite.java
bed1=${clipfile}.wsize${wsize}.regwsize${regwsize}.minreads${minreads}.clip${clip}.clipflk${clipflk}.mindis${mindis}.bed
feature_p6=${bed1/.cleaned.fastq.pcsort.qyname.bam.L1HSAligned.sc.leftvsright.bed.consensusbp/}
cp ${algn_hs_path}/${bed1} ${feature_path}/${feature_p6}
java -classpath ${tipseqjar} org/nyumc/TIPseqHunter2_20170616/P6_IdentificationOfExistingMobileDNASite ${feature_path} ${positive_anno_path} ${feature_p6} ${positive_anno_file} ${bed1flk} ${bed1chr} ${bed1s} ${bed1e} ${bed2chr} ${bed2s} ${bed2e} ${bed2add1} ${bed2add2} ${bed2add3} ${outnamekey1} ${ifheader}

# P7_IdentificationOfUniqueMatchToExistingMobileDNASite.java
feature_p7=${feature_p6/%.bed/}
feature_p7=${feature_p7}.${outnamekey1}
java -classpath ${tipseqjar} org/nyumc/TIPseqHunter2_20170616/P7_IdentificationOfUniqueMatchToExistingMobileDNASite ${feature_path} ${feature_p7} $sc $gs ${outnamekey2} ${ifheader}

# P8_ExtractEnzymeCuttingSite_v2.java
feature_p8=${feature_p7/%.bed/}
feature_p8=${feature_p8}.${outnamekey2}
java -Djava.awt.headless=true -Xmx50g -classpath ${tipseqjar}:${jfjarpath}:${jcommonpath}:${jtextpath} org/nyumc/TIPseqHunter2_20170616/P8_ExtractEnzymeCuttingSite_v2 ${pathezm} ${feature_path} $ezm ${feature_p8} $dis

# P9_DPperCSAndUniqueAlignProperAlignPercent_v2.java
feature_p9=${feature_p8}.csinfo
java -Xmx50g -classpath ${tipseqjar}:${samjarpath}:${mathjarpath} org/nyumc/TIPseqHunter2_20170616/P9_DPperCSAndUniqueAlignProperAlignPercent_v2 ${feature_path} ${algn_hs_path} ${feature_p9} ${outsortbam}

# P10_IdentificationOfL1HsPrimer5PrimeEnd.java
feature_p10=${feature_p9}.lm.read.IDs
feature_p10_reg=${feature_p9}.lm
java -Xmx50g -classpath ${tipseqjar}:${samjarpath}:${mathjarpath}:${biojavapath} org/nyumc/TIPseqHunter2_20170616/P10_IdentificationOfL1HsPrimer5PrimeEnd ${feature_path} ${feature_p10} ${feature_p10_reg} ${algn_te_path} ${outnamesortbamfile} ${l1hsseq} ${thresh_mismatch} ${preferred_mismatch} ${l1hskey}

########## second-step: build modeling and prediction #############

# P11_ModelBuildAndPredict_SVM.java
feature_p11=${feature_p10_reg}.l1hs
cp ${feature_path}/${feature_p11} ${model_path}/${feature_p11}
java -Djava.awt.headless=true -classpath ${tipseqjar}:${jfjarpath}:${jcommonpath}:${jtextpath} org/nyumc/TIPseqHunter2_20170616/P11_ModelBuildAndPredict_SVM ${model_path} ${feature_p11} ${readnum} ${l1hskey}
