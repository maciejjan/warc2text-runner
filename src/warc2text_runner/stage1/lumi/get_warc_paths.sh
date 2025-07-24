s3cmd ls -r $1 | awk '$4 ~ /.*.warc.gz/ { print $4; }'
