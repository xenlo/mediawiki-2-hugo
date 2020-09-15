#!/bin/bash

#######
#
# Description:
#   The goal of the script is to extract the data of a Mediawiki instance
#   and convert it into .md files that you can inject in your Hugo
#   static website.
#
# Credits:
#    Author: Laurent G (xenlo)
#    Source: TBD
#    License: Apache License 2.0
#

usage(){
    echo "Usage: ${0} [-v] [-i mediawiki_dir] [-o out_dir] [-t timezone] [-c charset]"
    echo "    -i mediawiki_dir   Specify the MediaWiki root directory as input (default: /var/www/mediawiki/)"
    echo "    -o out_dir         Specify output directory (default: ./out)"
    echo "    -t timezone        Specify your timezone offset (default: +02:00)"
    echo "    -c charset         Specify the DB charset (default: binary)"
    echo "    -f frontmatter     Specify a file with extra Front Matter entries"
    echo "    -w format_script   Specify a script which pre-processing the wiki content text,"
    echo "                       any script taking wiki text from standart input and return the edited wiki text as standard output"
    echo "    -m format_script   Specify a script which post-processing the MD content text,"
    echo "                       any script taking MarkDown text from standart input and return the edited MarkDown text as standard output"
    echo "    -M md_format       Specify the destination MarkDown format as pandoc will accept for --to argument,"
    echo "                       (default: \`markdown_strict+backtick_code_blocks\`)"
    echo "    -v                 Verbose"
    exit 1
}

validate_mediawiki_dir(){
    if [[ ! -d ${1} ]]; then
        echo "Error: ${1} is not a directory"
        exit 1
    fi
    if [[ ! -f ${1}/LocalSettings.php ]]; then
        echo "Error: File 'LocalSettings.php' not found in ${1}"
        exit 1
    fi
}

validate_out_dir(){
    if [[ -d ${1} ]]; then
        echo "Warning: ${1} already exist, this script may overwrite content!"
        read -p "Do you want to proceed anyway? " -n 1 -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
}

validate_extra_frontmatter(){
    if [[ ! -f ${1} ]]; then
        echo "Error: no file ${1}"
        exit 1
    fi
}

# Set few default values
wiki_preprocess="cat -"
md_postprocess="cat -"
md_format="markdown_strict+backtick_code_blocks"

while getopts 'hi:o:t:c:f:w:m:M:v' OPTION; do
  case "$OPTION" in
    i)
        mediawiki_dir="${OPTARG}"
        ;;
    o)
        out_dir="${OPTARG}"
        ;;
    t)
        timezone="${OPTARG}"
        ;;
    c)
        charset="${OPTARG}"
        ;;
    f)
        extra_frontmatter="${OPTARG}"
        ;;
    w)
        wiki_preprocess="./${OPTARG}"
        ;;
    m)
        md_postprocess="./${OPTARG}"
        ;;
    M)
        md_format="./${OPTARG}"
        ;;
    v)
        verbose=true
        ;;
    h|?)
        usage
        ;;
  esac
done

DEBUG=${verobse:=false}

WIKI_WEB_DIR=${mediawiki_dir:="/var/www/mediawiki/"}
validate_mediawiki_dir ${WIKI_WEB_DIR}
WIKI_WEB_DIR_ROOT=$(echo "${WIKI_WEB_DIR}" | cut -c 2-)

DB_SERV=$(grep "wgDBserver" ${WIKI_WEB_DIR}/LocalSettings.php | cut -d\" -f2)
DB_NAME=$(grep "wgDBname" ${WIKI_WEB_DIR}/LocalSettings.php | cut -d\" -f2)
DB_LOGIN=$(grep "wgDBuser" ${WIKI_WEB_DIR}/LocalSettings.php | cut -d\" -f2)
DB_PASS=$(grep '^\$wgDBpassword' ${WIKI_WEB_DIR}/LocalSettings.php | cut -d\" -f2)
DB_CHARSET=${charset:="binary"}

TIMEZONE_OFFSET=${timezone:="+02:00"}

DEST_DIR=${out_dir:="./out"}
validate_out_dir ${DEST_DIR}

NAME_SPACES=(
    [0]='main'
    [1]='talk'
    [2]='user'
    [3]='user_talk'
    [4]='project'
    [5]='project_talk'
    [6]='file'
    [7]='file_talk'
    [8]='mediawiki'
    [9]='mediawiki_talk'
    [10]='template'
    [11]='template_talk'
    [12]='help'
    [13]='help_talk'
    [14]='category'
    [15]='category_talk'
    )


mapfile name_spaces_ids < <(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
    SELECT DISTINCT
        page_namespace
    FROM
        page
    ;")

mapfile categories < <(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
    SELECT
        *
    FROM
        category
    ;")

mapfile pages < <(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
    SELECT
        p.page_id AS "page_id",
        CAST(p.page_title AS ${DB_CHARSET}) AS "page_title",
        p.page_namespace AS "page_namespace_id",
        r.rev_text_id AS "revision_id",
        DATE_FORMAT(r.rev_timestamp,'%Y-%m-%dT%H:%i:%s') AS "revision_timestamp",
        t.old_id AS "text_id",
        t.old_text AS "text_content",
        u.user_name AS "user_name"
    FROM
        page p
            INNER JOIN revision r
                ON p.page_latest = r.rev_id
            INNER JOIN text t
                ON r.rev_text_id = t.old_id
            INNER JOIN user u
                ON r.rev_user = u.user_id
    WHERE
        p.page_is_redirect = 0
    ;")

mapfile redirects < <(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
    SELECT
        CAST(p.page_title AS ${DB_CHARSET}) AS "redirect_title",
        t.old_text AS "redirect_content"
    FROM
        page p
            INNER JOIN revision r
                ON p.page_latest = r.rev_id
            INNER JOIN text t
                ON r.rev_text_id = t.old_id
    WHERE
        p.page_is_redirect = 1
    ;")

echo "Ok, so we have ${#pages[@]} pages in ${#name_spaces_ids[@]} NameSpaces and ${#categories[@]} Categories to migrate..."
echo ""

echo "Creation of the output directory structure..."
mkdir ${DEST_DIR}
for name_space_id in "${name_spaces_ids[@]}"; do
    mkdir ${DEST_DIR}/${NAME_SPACES[$name_space_id]}
done
echo ""

echo "Creation of the output files..."
for page in "${pages[@]}"; do
    IFS=$'\t' read -r page_id page_title page_namespace_id revision_id revision_timestamp text_id text_content user_name <<< "${page}"

    # Execute 2 extra SQL queries for the current page
    creation_timestamp=$(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
        SELECT
            DATE_FORMAT(MIN(rev_timestamp),'%Y-%m-%dT%H:%i:%s')
        FROM
            revision
        WHERE
            rev_page = ${page_id}
        ;")
    page_categories=$(mysql --host=${DB_SERV} --user=${DB_LOGIN} --password=${DB_PASS} --database=${DB_NAME} --batch --skip-column-names --execute="\
        SELECT
            CAST(cl_to AS ${DB_CHARSET})
        FROM
            categorylinks
        WHERE
            cl_from = ${page_id}
        ;")
    out_file=${DEST_DIR}/${NAME_SPACES[$page_namespace_id]}/${page_title//\//-}.md

    # Generate the Front Matters
    echo "  Generate ${out_file}"
    echo "---"                                                >  ${out_file}
    echo "title: \"${page_title//_/ }\""                      >> ${out_file}
    echo "author: ${user_name}"                               >> ${out_file}
    echo "date: ${creation_timestamp}${TIMEZONE_OFFSET}"      >> ${out_file}
    echo "lastmod: ${revision_timestamp}${TIMEZONE_OFFSET}"   >> ${out_file}
    echo "draft: false"                                       >> ${out_file}
    echo "slug: " >> ${out_file}
    echo "categories: "                                       >> ${out_file}
    while read page_category; do
        echo "  - ${page_category}"                           >> ${out_file}
    done < <(printf '%s\n' "${page_categories}")
    echo "tags: "                                             >> ${out_file}
    echo "aliases: "                                          >> ${out_file}
    if [[ -n "${extra_frontmatter}" ]]; then
        cat ${extra_frontmatter}                              >> ${out_file}
    fi
    echo "---" >> ${out_file}

    if [[ ${NAME_SPACES[$page_namespace_id]} == "file" ]]; then
        # Display the image in the corresponding .md file
        echo "![${page_title}](images/${page_title//\//-})" >> ${out_file}
    else
        # Insert the context formated in MD
        echo -e "${text_content}" | ${wiki_preprocess} | pandoc --from=mediawiki --to=${md_format} --atx-headers | ${md_postprocess}>> ${out_file}
    fi
    echo ""                                                   >> ${out_file}
done

echo "Add alias for each redirect"
for redirect in "${redirects[@]}"; do
    IFS=$'\t' read -r redirect_title redirect_content <<< "${redirect}"
    cleanned_content=$(echo ${redirect_content} | sed -e 's/^#REDIRECT.*\[\[//' | sed -e 's/\]\].*$//' | sed -e 's/ /_/g')
    if [[ ${cleanned_content} =~ ":" ]]; then
        redirect_page=$(echo ${cleanned_content} | cut -d':' -f2)
        redirect_namespace=$(echo ${cleanned_content} | cut -d':' -f1)
        redirect_namespace=$(echo ${redirect_namespace} | sed 's/Discussion/talk/')
    else
        redirect_page=${cleanned_content}
        redirect_namespace="main"
    fi
    out_file=${DEST_DIR}/${redirect_namespace}/${redirect_page//\//-}.md
    echo "  Alias for ${out_file}"
    sed -i -e "s/^aliases: /aliases: \n  - ${redirect_title}/" ${out_file}
done
echo ""

echo "Copy the images"
mkdir -p ${DEST_DIR}/images/
for ext in png PNG jpg JPG jpeg JPEG gif GIF; do
    find ${WIKI_WEB_DIR}/images/ -name "*.${ext}" \
        -not -name "*[0-9]px-*" \
        -not -path "*/deleted/*" \
        -not -path "*/temp/*" \
        -not -path "*/thumb/*" \
        -not -path "*/archive/*" \
        -exec cp {} ${DEST_DIR}/images/ \;
done
echo ""

