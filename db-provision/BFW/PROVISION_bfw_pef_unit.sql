-- Provisions the isolated BFW unit-test database used by:
--   backend/api/src/test/resources/application-test.yaml
--   backend/jBatch/src/test/resources/application-test.yaml
--   backend/api/src/main/resources/application-ui-test.yaml
--
-- Run against the local MySQL server at 127.0.0.1:3306 with an account that has
-- CREATE DATABASE / CREATE USER / GRANT privileges (e.g. root). Requires explicit
-- confirmation per this repository's Real Database Change Confirmation Rule before
-- running against any shared or persistent instance.
--
-- Table definitions below are copied verbatim from Database/BFW/Table/*.sql
-- (single source of truth). Keep both in sync if a table changes.

CREATE DATABASE IF NOT EXISTS bfw_pef_unit;

CREATE USER IF NOT EXISTS 'bfw_pef_unit'@'%' IDENTIFIED BY 'bfw_pef_unit';
GRANT ALL PRIVILEGES ON bfw_pef_unit.* TO 'bfw_pef_unit'@'%';
FLUSH PRIVILEGES;

USE bfw_pef_unit;

-- Source: Database/BFW/Table/TB_R_BATCH_QUEUE.sql
DROP TABLE IF EXISTS TB_R_BATCH_QUEUE;

CREATE TABLE TB_R_BATCH_QUEUE
(
  QUEUE_NO      INT AUTO_INCREMENT              NOT NULL,
  REQUEST_ID    VARCHAR(255)                    NOT NULL,
  BATCH_ID      VARCHAR(255)                    NOT NULL,
  REQUEST_BY    VARCHAR(255)                    NOT NULL,
  PARAMETERS    VARCHAR(255),
  SUPPORT_ID    VARCHAR(255),
  PROJECT_CODE  VARCHAR(255),
  DESCRIPTION   VARCHAR(255),
  APP_ID        VARCHAR(255),
  REQUEST_TIME  DATETIME(6)                     DEFAULT CURRENT_TIMESTAMP(6),
  EXEC_TIME_OUT INT,
  CONSTRAINT IX_PK_BATCH_QUEUE_01 PRIMARY KEY (QUEUE_NO)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- Source: Database/BFW/Table/TB_H_BATCH_QUEUE.sql
DROP TABLE IF EXISTS TB_H_BATCH_QUEUE;

CREATE TABLE TB_H_BATCH_QUEUE
(
  QUEUE_NO      INT                             NOT NULL,
  REQUEST_ID    VARCHAR(255)                    NOT NULL,
  BATCH_ID      VARCHAR(255)                    NOT NULL,
  REQUEST_BY    VARCHAR(255)                    NOT NULL,
  PARAMETERS    VARCHAR(255),
  SUPPORT_ID    VARCHAR(255),
  PROJECT_CODE  VARCHAR(255),
  DESCRIPTION   VARCHAR(255),
  APP_ID        VARCHAR(255),
  REQUEST_TIME  DATETIME(6)                     DEFAULT CURRENT_TIMESTAMP(6),
  EXEC_TIME_OUT INT,
  CONSTRAINT IX_PK_H_BATCH_QUEUE_01 PRIMARY KEY (QUEUE_NO)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Source: Database/BFW/Table/TB_M_BATCH.sql
DROP TABLE IF EXISTS TB_M_BATCH;

CREATE TABLE TB_M_BATCH
(
  BATCH_ID          VARCHAR(10)                 NOT NULL,
  PROJECT_CODE      VARCHAR(3)                  NOT NULL,
  BATCH_NAME        VARCHAR(100),
  PRIORITY_LEVEL    INT                         DEFAULT 0,
  CONCURRENCY_FLAG  CHAR(1)                     DEFAULT 'N',
  RUNNING_COUNT     INT                         NOT NULL,
  RUN_AS            VARCHAR(255)                NOT NULL,
  SHELL             VARCHAR(255)                NOT NULL,
  CREATE_BY         VARCHAR(255),
  CREATE_DT         DATETIME(6)                 DEFAULT CURRENT_TIMESTAMP(6) NOT NULL,
  UPDATE_BY         VARCHAR(255),
  UPDATE_DT         DATETIME(6)                 DEFAULT CURRENT_TIMESTAMP(6) NOT NULL,
  SUPPORT_ID                  VARCHAR(10),
  DEGRADED_ORPHAN_REPEAT      INT                         NULL,
  DEGRADED_ORPHAN_LAST_MAIL_DT DATETIME(6)               NULL,
  CONSTRAINT IX_PK_M_BATCH_01 PRIMARY KEY (PROJECT_CODE, BATCH_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Source: Database/BFW/Table/TB_L_BATCH_STATUS_LOG.sql
DROP TABLE IF EXISTS TB_L_BATCH_STATUS_LOG;

CREATE TABLE TB_L_BATCH_STATUS_LOG
(
  SEQ_NO        BIGINT AUTO_INCREMENT           NOT NULL,
  QUEUE_NO      INT                             NOT NULL,
  MESSAGE       VARCHAR(200)                    NOT NULL,
  RUN_DATE      DATETIME                        NOT NULL,
  DESCRIPTION   VARCHAR(200),
  CONSTRAINT PK_TB_BATCH_STATUS_LOG PRIMARY KEY (SEQ_NO)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4;

-- Note: Oracle original started AUTO_INCREMENT at 51 (START WITH 51).

-- Source: Database/BFW/Table/TB_R_QUEUE_MANAGER_LEASE.sql
DROP TABLE IF EXISTS TB_R_QUEUE_MANAGER_LEASE;

CREATE TABLE TB_R_QUEUE_MANAGER_LEASE
(
  LEASE_NAME        VARCHAR(100)                NOT NULL,
  OWNER_NODE_ID     VARCHAR(255),
  LEASE_UNTIL       DATETIME(6),
  LAST_HEARTBEAT_DT DATETIME(6),
  CREATE_DT         DATETIME(6)                 DEFAULT CURRENT_TIMESTAMP(6) NOT NULL,
  UPDATE_DT         DATETIME(6)                 DEFAULT CURRENT_TIMESTAMP(6) NOT NULL,
  CONSTRAINT IX_PK_QM_LEASE_01 PRIMARY KEY (LEASE_NAME)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
