-- ============================================================
-- 실습 테이블 (MySQL이 처음 실행될 때 자동으로 한 번 실행됨)
--
-- 일부러 PRIMARY KEY 외에는 인덱스를 하나도 만들지 않았습니다.
-- = "인덱스 전" 상태. 실험마다 인덱스를 직접 추가하고 비교합니다.
--
-- 외래 키(FOREIGN KEY)도 일부러 선언하지 않았습니다.
-- InnoDB는 외래 키를 만들면 그 컬럼에 인덱스를 "자동으로" 만들어서
-- "인덱스 전" 상태를 망가뜨리기 때문입니다. (E02 실험에서 직접 확인)
-- ============================================================

USE lab;

-- 회원
CREATE TABLE users (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    email       VARCHAR(100) NOT NULL,              -- 중복되면 안 되는 값 (UNIQUE 후보)
    phone       VARCHAR(20)  NOT NULL,              -- 숫자처럼 보이지만 문자열 (형변환 실험용)
    nickname    VARCHAR(50)  NOT NULL,
    status      VARCHAR(20)  NOT NULL,              -- ACTIVE / DORMANT / WITHDRAWN
    created_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- 판매자
CREATE TABLE sellers (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    created_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- 카테고리
CREATE TABLE categories (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- 상품
CREATE TABLE products (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    seller_id    BIGINT       NOT NULL,
    category_id  BIGINT       NOT NULL,
    name         VARCHAR(200) NOT NULL,
    price        INT          NOT NULL,
    stock        INT          NOT NULL,
    status       VARCHAR(20)  NOT NULL,             -- ON_SALE / SOLD_OUT / HIDDEN
    created_at   DATETIME     NOT NULL,
    updated_at   DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- 게시글 (무한 스크롤 피드)
CREATE TABLE posts (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    user_id     BIGINT       NOT NULL,
    title       VARCHAR(200) NOT NULL,
    content     TEXT         NOT NULL,              -- 큰 본문 (SELECT * 의 비용 실험용)
    status      VARCHAR(20)  NOT NULL,              -- PUBLISHED(약 90%) / DRAFT / DELETED
    like_count  INT          NOT NULL DEFAULT 0,    -- 반정규화 컬럼. 처음엔 0 (E12에서 채움)
    created_at  DATETIME     NOT NULL,
    updated_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- 좋아요 (원본 데이터)
CREATE TABLE likes (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    post_id     BIGINT       NOT NULL,
    user_id     BIGINT       NOT NULL,
    created_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;
