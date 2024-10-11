# use one of the images from this repository: https://github.com/centreborelli/ipol-docker-images/
FROM registry.ipol.im/ipol:v1-py3.9

# copy the code to $bin
ENV bin /workdir/bin
RUN mkdir -p $bin
WORKDIR $bin
COPY . .

WORKDIR $bin/extendexpof
RUN cp runeef.m run_ef.m eef.m multiscaleBlendingColor.m remapFun.m robustNormalization.m image_registration.sh composeHomographies.m exposureFusion $bin

WORKDIR $bin/Midway_src
RUN make
RUN cp $bin/Midway_src/bin/midway $bin

WORKDIR $bin/mInverseCompositional_1.00
RUN make
RUN cp inverse_compositional_algorithm $bin

RUN apt-get update && apt-get install -y libgsl-dev
WORKDIR $bin/bspline_1.00/src
RUN cmake CMakeLists.txt
RUN make
RUN cp bspline compute_bspline hom4p $bin
WORKDIR $bin

# the execution will happen in the folder /workdir/exec
# it will be created by IPOL

# some QoL tweaks
ENV PYTHONDONTWRITEBYTECODE 1
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION python
ENV PATH $bin:$PATH

# $HOME is writable by the user `ipol`, but 
ENV HOME /home/ipol
# chmod 777 so that any user can use the HOME, in case the docker is run with -u 1001:1001
RUN groupadd -g 1000 ipol && useradd -m -u 1000 -g 1000 ipol -d $HOME && chmod -R 777 $HOME
RUN apt-get update && apt-get install -y octave liboctave-dev
RUN octave --eval "pkg install -forge image" && octave --eval "pkg load image"
USER ipol