#!/bin/bash

KERNEL_DIR=linux
CONFIGS_DIR=configs

help() {
    printf "Usage: $0 [OPTIONS] [CONFIG]\n"
    printf "Make the preparations needed to the kernel source for a given config.\n"
    printf "\n"
    printf "Options:\n"
    printf "  -h,--help         Print this message and exit\n"
    printf "  -d,--dry          Pull the kernel source without any config\n"
    printf "  -l,--list-configs List all available configurations\n" 
    printf "\n"
    printf "Config:\n"
    printf "  The name of the config to be initialized.\n"
}

function list_configs() {
    POSSIBLE_CONFIGS=$(find ${CONFIGS_DIR} -maxdepth 1 -mindepth 1 -type d -print | xargs -n 1 basename)
    if [[ -z "$POSSIBLE_CONFIGS" ]]; then
        printf "Configs directory \"${CONFIGS_DIR}\" doesn't have any (valid) configs\n";
        exit
    fi
    
    printf "Found configs:\n"
    for CONFIG in ${POSSIBLE_CONFIGS};
    do
        printf "  ${CONFIG}\n"
    done
}

function config_is_valid() {
    if [[ -z "$1" ]]; then
        echo "n" 
        return
    fi

    if ! [[ -f "${CONFIGS_DIR}/$1/kconfig" ]]; then
        echo "n"
        return
    fi

    if ! [[ -f "${CONFIGS_DIR}/$1/wants_tag" ]]; then
        echo "n"
        return
    fi

    echo "y"
}

if [[ $# -eq 0 ]]; then
    help
    exit
fi

DRY_RUN=n

while [[ $# -gt 0 ]]
do
	key="$1"
	case "$key" in
		"-h"|"--help")
			help
            shift 1
            exit
		;;
		"-l"|"--list-configs")
            list_configs
            shift 1
            exit
		;;
        "-d"|"--dry")
            DRY_RUN=y
            shift 1
        ;;
		*)
            if [[ -z "${SELECTED_CONFIG}" ]]; then
                SELECTED_CONFIG=${key} 
            else
                printf "Too many positional arguments.\n"
                exit 1
            fi

            shift 1
		;;
	esac
done

if [[ -z "${SELECTED_CONFIG}" && "${DRY_RUN}" == "n" ]]; then
    printf "No config was specified.\n"
    exit 1
fi

IS_CONFIG_VALID=$(config_is_valid ${SELECTED_CONFIG})
if [[ "${IS_CONFIG_VALID}" == "n" && "${DRY_RUN}" == "n" ]]; then
    printf "Config \"${SELECTED_CONFIG}\" is invalid.\n"
    exit 1
fi

if ! [[ -d "${KERNEL_DIR}" ]]; then
    git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ${KERNEL_DIR}
fi

if [[ "${DRY_RUN}" == "y" ]]; then
    exit # We're done
fi

# symlink kconfig
ln -sfr ${CONFIGS_DIR}/${SELECTED_CONFIG}/kconfig ${KERNEL_DIR}/.config

# checkout a new branch with the wanted tag
TAG=$(cat ${CONFIGS_DIR}/${SELECTED_CONFIG}/wants_tag)
cd ${KERNEL_DIR}
git branch ${SELECTED_CONFIG} ${TAG}
git checkout ${SELECTED_CONFIG}
cd - > /dev/null

