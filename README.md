# TIPseqHunter
> Dockerfile for TIPseqHunter pipeline

## Getting Started

### Motivation

[`TIPseqHunterPipelinejar.sh`](https://github.com/galantelab/tipseq_hunter/blob/master/bin/TIPseqHunterPipelineJar.sh) and [`TipseqHunterPipelineJarSomatic.sh`](https://github.com/galantelab/tipseq_hunter/blob/master/bin/TIPseqHunterPipelineJarSomatic.sh) need some java libraries as well as biological annotations and genome indexes. Therefore, manipulating all these dependencies ends up being troublesome. For that reason, [`docker`](https://www.docker.com/) is a good approach to overcome this kind of problem, because it has the ability to encapsulate the whole environment needed by the application, so that it can run in different machines. As result, the pipeline becomes more reliable and reproducible.

### Prerequisities

In order to run this container you'll need docker installed.

* [Windows](https://docs.docker.com/windows/started)
* [OS X](https://docs.docker.com/mac/started/)
* [Linux](https://docs.docker.com/linux/started/)

### Acquiring TIPseqHunter Image

#### Manual Installation

Clone this repository:

`$ git clone https://github.com/galantelab/tipseq_hunter.git`

> TIPseqHunter needs biological annotation files that occupy a few gigabytes. In order to deal with these files, we created a gzipped tarball which is currently hosted in AWS. So, to successfully build the docker image, it is required to define the variable `tarball_url`, which may point to the tarball URL, to the **docker build** command.

Inside the tipseq_hunter folder, build the image:

`$ docker build --build-arg tarball_url=https://bioinfohsl-webusers.s3.amazonaws.com/tmiller/tipseq_hunter_data.tar.gz -t tipseqhunter .`

Another and better option is using the [`Makefile`](https://github.com/galantelab/tipseq_hunter/blob/master/Makefile) inside tipseq_hunter folder:

`$ make build`

#### Pulling Image

Pull **tipseqhunter** image from [dockerhub](https://hub.docker.com) registry:

`$ docker pull galantelab/tipseqhunter`

Or using Makefile:

`$ make pull`

> Pay attention! You will need to use `sudo` in the commands if you are not member of the docker group

### Usage

Once installed the docker image, the user may apply the [`Makefile`](https://github.com/galantelab/tipseq_hunter/blob/master/Makefile), in order to automate the process of creating the container and running the pipeline, as well as using the ordinary **docker run** command.

#### Examples with docker run

By default the **TIPseqHunterPipelinejar/TipseqHunterPipelineJarSomatic** runs in a container-private folder. You need to change this using flags, like user (-u), current directory, and volumes (-w and -v). It is important to mount the fastq directory and output directory, that way **docker** can find the required files:

```
$ docker run \
	--rm \
	-u $(id -u):$(id -g) \
	-v path_to_fastq_folder:path_to_fastq_folder \
	-v path_to_output_folder:path_to_output_folder \
	-w path_to_output_folder \
	tipseqhunter \
		TIPseqHunterPipelineJar.sh path_to_fastq_folder path_to_output_folder fastq_r1 key_r1 key_r2 number_of_reads
```

That command sets the user UID:GID, mounts the *input/ouput* directories, sets the current working directory as the *output* folder and, finally, runs **TIPseqHunterPipelinejar.sh** script. In the end, the container is automatically removed.

The **TIPseqHunterPipelinejar/TIPseqHunterPipelineJarSomatic** runs based on some cutoffs. There is a default value to each one, but you might change it through environment variables. The best way to do it is by a configuration file to the **docker run** command. You can find an example in [`config.env`](https://github.com/galantelab/tipseq_hunter/blob/master/config.env) file, which is already set to the default values. To use it with **docker run**:

```
$ docker run \
	--rm \
	--env-file=config.env \
	-u $(id -u):$(id -g) \
	-v path_to_fastq_folder:path_to_fastq_folder \
	-v path_to_output_folder:path_to_output_folder \
	-w path_to_output_folder \
	tipseqhunter \
		TIPseqHunterPipelineJar.sh path_to_fastq_folder path_to_output_folder fastq_r1 key_r1 key_r2 number_of_reads
```

#### Examples with Makefile

The `Makefile` can be used to `build`, `pull` and `run` the **TIPseqHunter** scripts inside **docker**:

```
$ make

help                           This help
build                          Build the image
build-nc                       Build the image without caching
pull                           Pull the latest tagged image from the dockerhub registry
remove                         Remove the lattest tagged image
run                            Run TIPseqHunter pipeline completely
run-pipeline                   Run TIPseqHunterPipelineJar.sh
run-pipeline-somatic           Run TIPseqHunterPipelineJarSomatic.sh
up                             Pull and run TIPseqHunter pipeline completely
stop                           Stop and remove a running container
version                        Output the current version

```

When running the pipeline, the `Makefile` automatically searches for a file named `config.env` in the current directory, so
if it exists, you can just call:

`$ make run`

Or use another file with a different name:

`$ make run CONFIG=another_config.txt`

The arguments to **TIPseqHunterPipelinejar/TIPseqHunterPipelineJarSomatic** can be passed into the `config.env` or through the command line:

```
$ make run \
	CONFIG=another_config.txt \
	INPUT_DIR=fastq_folder \
	OUTPUT_DIR=ouput_folder \
	FASTQ_R1=example_R1.fa \
	KEY_R1=R1 \
	KEY_R2=R2 \
	READ_NUM=123456
```

That is it! :smile:
