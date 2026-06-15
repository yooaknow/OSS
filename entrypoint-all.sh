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

# MySQL 준비 대기 — 소켓 방식으로 확인
# (Ubuntu MySQL root 계정은 auth_socket 플러그인 사용 → TCP 인증 불가)
echo "MySQL 준비 대기 중..."
for i in $(seq 1 60); do
    if mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
        echo "MySQL 준비 완료"
        break
    fi
    sleep 1
done

# DB/유저 초기화 — 소켓으로 root 접속
mysql --socket=/var/run/mysqld/mysqld.sock -u root <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
CREATE DATABASE IF NOT EXISTS travel_rec;
CREATE USER IF NOT EXISTS 'recuser'@'%' IDENTIFIED WITH mysql_native_password BY 'recpass';
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
