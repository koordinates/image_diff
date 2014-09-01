#!/bin/bash

# set -x

FORMAT=PNG
EXT=png

GIT_REMOTE='git@github.com:koordinates/image_diff.git'

SRC_DIR=${1}
TEMP_DIR=$(mktemp -d)
METHODS="near bilinear cubic"

mkdir ${TEMP_DIR}/build

echo "Copying source files from ${SRC_DIR} to ${TEMP_DIR}"

find ${SRC_DIR} -name '*.jp2' -execdir cp {} ${TEMP_DIR}/build/{} \;

pushd ${TEMP_DIR}

    git init
    git remote add origin ${GIT_REMOTE}

popd

cp ${0} ${TEMP_DIR}/script.sh

pushd ${TEMP_DIR}
    echo 'Test images for prospective GDAL improvements.
Test images fetched from LINZ Data Service
https://data.linz.govt.nz/layer/767-nz-mainland-topo50-maps/
https://data.linz.govt.nz/layer/1049-nz-orthophotos-2000-2001/' > README

    git add README script.sh
    git commit -m "Readme and script used to generate the diffs"

popd

# Translate to 1/4, warp to 1/8
pushd ${TEMP_DIR}/build/

    for method in ${METHODS}
    do
        for src in $(ls *.jp2)
        do
            BASE_NAME=$(basename ${src})
            BASE_NAME="${BASE_NAME%.*}"
            echo -n "Translating ${img} "
            gdal_translate -outsize 25% 25% ${src} 1_4_${BASE_NAME}.tif

            gdalinfo 1_4_${BASE_NAME}.tif | grep "Pixel Size"
            xy=$(gdalinfo 1_4_${BASE_NAME}.tif | grep "Pixel Size" | grep -Po '\d+.\d+' | tr '\n' ' ')
            x=$(echo $xy | grep -Po '\d+\.\d+' | head -n1)
            y=$(echo $xy | grep -Po '\d+\.\d+' | tail -n1)
            x2=$(echo "$x * 2" | bc)
            y2=$(echo "$y * 2" | bc)

            echo -n "Warping ${img} with ${method} "
            gdalwarp -r ${method} -tr ${x2} ${y2} 1_4_${BASE_NAME}.tif 1_8_${BASE_NAME}.tmp.tif

            echo "Translating to ${FORMAT}"
            gdal_translate -of ${FORMAT} 1_8_${BASE_NAME}.tmp.tif 1_8_${BASE_NAME}.${EXT}

            echo ""

            for comparison in translate_to_1_8 translate_to_1_2
            do
                final_name="${method}_vs_${comparison}_${BASE_NAME}.${EXT}"
                cp 1_8_${BASE_NAME}.${EXT} ${TEMP_DIR}/${final_name}
                git add ${TEMP_DIR}/${final_name}
            done

            rm 1_4_${BASE_NAME}.tif 1_8_${BASE_NAME}.tmp.tif 1_8_${BASE_NAME}.${EXT}
            rm -f *.aux.xml
        done
    done

popd

pushd ${TEMP_DIR}

    git commit -m "Translate to 1/4 then warp to 1/8"

popd

# translate to 1/2, warp to 1/8
pushd ${TEMP_DIR}/build/

    for method in ${METHODS}
    do
        for src in $(ls *.jp2)
        do
            BASE_NAME=$(basename ${src})
            BASE_NAME="${BASE_NAME%.*}"
            echo -n "Translating ${img} "
            gdal_translate -outsize 50% 50% ${src} 1_2_${BASE_NAME}.tif

            gdalinfo 1_2_${BASE_NAME}.tif | grep "Pixel Size"
            xy=$(gdalinfo 1_2_${BASE_NAME}.tif | grep "Pixel Size" | grep -Po '\d+.\d+' | tr '\n' ' ')
            x=$(echo $xy | grep -Po '\d+\.\d+' | head -n1)
            y=$(echo $xy | grep -Po '\d+\.\d+' | tail -n1)
            x2=$(echo "$x * 4" | bc)
            y2=$(echo "$y * 4" | bc)

            echo -n "Warping ${img} with ${method} "
            gdalwarp -r ${method} -tr ${x2} ${y2} 1_2_${BASE_NAME}.tif 1_8_${BASE_NAME}.tmp.tif

            echo "Translating to ${FORMAT}"
            gdal_translate -of ${FORMAT} 1_8_${BASE_NAME}.tmp.tif 1_8_${BASE_NAME}.${EXT}

            echo ""

            final_name="${method}_vs_translate_to_1_2_${BASE_NAME}.${EXT}"
            cp 1_8_${BASE_NAME}.${EXT} ${TEMP_DIR}/${final_name}
            git add ${TEMP_DIR}/${final_name}

            rm 1_2_${BASE_NAME}.tif 1_8_${BASE_NAME}.tmp.tif 1_8_${BASE_NAME}.${EXT}
            rm -f *.aux.xml
        done
    done

popd

# translate to 1/8
pushd ${TEMP_DIR}/build/

    for src in $(ls *.jp2)
    do
        BASE_NAME=$(basename ${src})
        BASE_NAME="${BASE_NAME%.*}"
        echo -n "Translating ${img} "
        gdal_translate -of ${FORMAT} -outsize 12.5% 12.5% ${src} 1_8_${BASE_NAME}.${EXT}

        echo ""

        for method in ${METHODS}
        do
            final_name="${method}_vs_translate_to_1_8_${BASE_NAME}.${EXT}"
            cp 1_8_${BASE_NAME}.${EXT} ${TEMP_DIR}/${final_name}
            git add ${TEMP_DIR}/${final_name}
        done

        rm 1_[48]_${BASE_NAME}.${EXT}
    done

popd

pushd ${TEMP_DIR}

    git commit -m "Translate to 1/8"
    git push -f

popd

# rm -rf ${TEMP_DIR}
