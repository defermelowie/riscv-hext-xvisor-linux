ARG RISCV_CI=ghcr.io/defermelowie/riscv-hext-ci-env

# --------------------------------------------------------------
# Build csim emulator
# --------------------------------------------------------------

FROM ubuntu:latest as csim

# Update package list and install dependencies
RUN apt-get update && apt-get install zlib1g-dev pkg-config libgmp-dev z3 opam -y

# Build csim emulator
WORKDIR /hyp/sim/sail
COPY sim/sail .
RUN opam init -y && opam install sail -y
RUN eval $(opam env) && make csim ARCH=RV64

# --------------------------------------------------------------
# Build linux
# --------------------------------------------------------------

FROM $RISCV_CI/toolchain:latest as linux-builder

# Install build dependencies
RUN apt-get install device-tree-compiler cpio bison flex bc -y

# Build linux binaries
WORKDIR /hyp
COPY . .
RUN make setup
RUN make -f linux.mk

# ------------------------------
# Linux on spike emulator
# ------------------------------

FROM $RISCV_CI/spike:latest as linux-spike
COPY --from=linux-builder /hyp/target/* /hyp/

# ------------------------------
# Linux on csim emulator
# ------------------------------

FROM csim as linux-csim
COPY --from=linux-builder /hyp/target/* /hyp/

# --------------------------------------------------------------
# Build xvisor
# --------------------------------------------------------------

FROM $RISCV_CI/toolchain:latest as xvisor-builder

# Install build dependencies
RUN apt-get install device-tree-compiler cpio bison flex bc -y

# Build xvisor binaries
WORKDIR /hyp
COPY . .
RUN make setup
RUN make -f xvisor.mk

# ------------------------------
# Xvisor on spike emulator
# ------------------------------

FROM $RISCV_CI/spike:latest as xvisor-spike
COPY --from=xvisor-builder /hyp/target/* /hyp/

# ------------------------------
# Xvisor on csim emulator
# ------------------------------

FROM csim as xvisor-csim
COPY --from=xvisor-builder /hyp/target/* /hyp/
