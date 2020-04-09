Additional NIMAS ready examples can be found [here](http://aem.cast.org/creating/nimas-exemplars.html)

### OCX to NIMAS conversion

Build the image:

```
$ docker build -t paranoicsan/ocx2nimas .
```

Start the container:

TODO: Place here direct call to launch ruby script to perform action immediately

```bash
$ docker run --rm --name ocx2nimas -v $(pwd):/app -it paranoicsan/ocx2nimas
```

### NIMAS fileset Validation

The NIMAS fileset source files are inside `nimas-fileset` directory

Build the image:

```bash
$ docker build -t paranoicsan/pipeline-assembly-cli .
```

Start the container:

```bash
$ docker run --rm --name nimas -e PIPELINE2_WS_AUTHENTICATION=false -v $(pwd):/app -it paranoicsan/pipeline-assembly-cli
```

To manually start the validation process connect to container and start validation:

```bash
$ docker exec -ti nimas bash
$ /opt/daisy-pipeline2/cli/dp2 nimas-fileset-validator --input-opf g6.wc.sp.opf --data g6.wc.sp.zip --output reports
```
