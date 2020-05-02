ARG K_COMMIT
FROM runtimeverificationinc/kframework-k:ubuntu-bionic-${K_COMMIT}

RUN    apt-get update         \
    && apt-get upgrade --yes  \
    && apt-get install --yes  \
                       pandoc

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers    \
    && groupadd -g $GROUP_ID user                             \
    && useradd -m -u $USER_ID -s /bin/sh -g user -G sudo user
