# MediaWiki-2-Hugo #
Migration script from MediaWiki to Hugo

## Intro ##
This is a shell script I wrote to migrate my MediaWiki instance into a Hugo static website.

In my use case, my MediaWiki instance was hosting several notes and HowTo's. So, it was a quite small instance (256 pages in 8 NameSpaces and 16 Categories illustrated by 61 images). And even, it takes ~25sec to process. This is certainly not the best approach to migrate huge instance of MediaWiki. Nevertheless, as I didn't found anything similar doing that, I think this script could really help other, even it should be improved.

## How To use it? ##
The useful variables are customizable via arguments of the shell script.
```
xenlo@red-carpet:~/Scripts/$ ./mediawiki-2-hugo.sh -h
./mediawiki-2-hugo.sh : option non permise -- h
Usage: ./mediawiki-2-hugo.sh [-v] [-i mediawiki_dir] [-o out_dir] [-t timezone] [-c charset]
    -i mediawiki_dir   Specify the MediaWiki root directory as input (default: /var/www/mediawiki/)
    -o out_dir         Specify output directory (default: ./out)
    -t timezone        Specify your timezone offset (default: +02:00)
    -c charset         Specify the DB charset (default: binary)
    -v                 Verbose
```

So simply run the script, eventually with sudo as apache user (if yours don't have read access to the MediaWiki directory).
```
sudo -u www-data ./mediawiki-2-hugo.sh -i /var/www/my_wiki -o /tmp/output
```

## What does this script? ##
The script will first load the credentials from `LocalSettings.php` file and use it to read all wiki pages data in the database.
From there, ti generates in a destination directory (`DEST_DIR` is set as `./out` by default) a structure of subdirectories which matches the [MediaWiki namespaces](https://www.mediawiki.org/wiki/Manual:Namespace#Built-in_namespaces).

Then for each wiki page (each record of `page` in the SQL DB) it will generate a `.md` file. And each file will be filled in with servral attributes ([front matters](https://gohugo.io/content-management/front-matter/) in Hugo language) and with the page's content.

### Front Matters ###
This script is fetching and filling the following data:
- **title**: Which is the `page.page_title` where I apply a replace of the '`_`' by spaces
- **author**: The `user.user_name` of MediaWiki user who created the page.
- **date**: The oldest `revision.rev_timestamp` in the database for that page.
- **lastmod**: The latest `revision.rev_timestamp` in the database for that page.
- **draft**: Always false, ... (I think to put true for the stuff that are not from man name_space)
- **categories**: The list of categories linked to that page (`categorylinks.cl_to`)
- **tags**: Left empty for now...
- **aliases**: The list of redirect/renamed page name (`page.page_title` when `page.page_is_redirect = 1`).

### Content ###
And of course, it fetch the content of each pages in its latest version, and convert it in MarkDown (github flavour).

:warning: This use pandoc tool to convert the MediaWiki syntax into the MarkDown. Please ensure that `pandoc` is accessible 

## How does it works? / What does it need? ##

### Requirements ###
- [Pandoc](https://pandoc.org/) installed

### Access ###
- Read access to file `${WIKI_WEB_DIR}/LocalSettings.php`
- Read access to directory `${WIKI_WEB_DIR}/images/`
- SQL connectivity (credentials collected from `LocalSettings.php`)

## What is the status of this ##
It's working but far from perfect. Lot's of stuff are not handled as you can see in the list here under.

### ToDo ###
- Ensure it generate a nicer post header
- Handle the verbosity
- Manage template into html snippet
- Further test of output in Hugo
- Correct the [known bugs](https://github.com/xenlo/mediawiki-2-hugo/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

### Later, Further Improvements ###
- Complete the tags with ...?
- Re-factoring a bit with functions
- Better exploit possibilities of pandoc ([metadata variables](https://pandoc.org/MANUAL.html#metadata-variables))??


### Won't do ###
- **Copy the files**: Except the images, I don't have any files on my wiki.
- **Slug**: I took the page's name from MediaWiki (which is the title with spaces substituted by underscores) as files name. So in the end of the url remain the same.
- **Front matters of theme**: In the theme I plan to use ([Tranquilpeak](https://github.com/kakawait/hugo-tranquilpeak-theme/)) I don't saw any interesting attribute that could be fed with data from the MediaWiki.


## License ##
Copyright 2019 Laurent G (xenlo)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

