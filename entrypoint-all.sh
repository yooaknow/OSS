#!/bin/bash
set -e

# ── MySQL 초기화 ───────────────────────────────────────────────────────────────
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/lib/mysql /var/log/mysql

# 데이터 디렉터리가 비어 있으면 초기화
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi

# MySQL 백그라운드 시작
mysqld_safe --user=mysql &

# MySQL 준비 대기
echo "MySQL 준비 대기 중..."
for i in $(seq 1 60); do
    if mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then
        echo "MySQL 준비 완료"
        break
    fi
    sleep 1
done

# DB/유저 초기화
mysql -h 127.0.0.1 -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS travel_rec;
CREATE USER IF NOT EXISTS 'recuser'@'%' IDENTIFIED BY 'recpass';
GRANT ALL PRIVILEGES ON travel_rec.* TO 'recuser'@'%';
FLUSH PRIVILEGES;
USE travel_rec;
CREATE TABLE IF NOT EXISTS recommendation_history (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    party_size   VARCHAR(20)  NOT NULL,
    duration     VARCHAR(20)  NOT NULL,
    activity     VARCHAR(30)  NOT NULL,
    budget       VARCHAR(20)  NOT NULL,
    season       VARCHAR(10)  NOT NULL,
    results_json JSON,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

echo "DB 초기화 완료. supervisord 시작..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
