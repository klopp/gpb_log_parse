use test_base;
-- CREATE TABLE "message" --------------------------------------
CREATE TABLE `message`( 
    `created` Timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `id` VarChar( 255 ) NOT NULL,
    `int_id` Char( 16 ) NOT NULL,
    `str` Text NOT NULL,
    `status` TinyInt( 1 ) NULL DEFAULT 0,
    `address` VarChar( 255 ) NULL,
    PRIMARY KEY ( `id` ) );
-- CREATE INDEX "message_created_idx" --------------------------
CREATE INDEX `message_created_idx` USING BTREE ON `message`( `created` );
-- CREATE INDEX "message_int_id_idx" ---------------------------
CREATE INDEX `message_int_id_idx` USING BTREE ON `message`( `int_id` );
-- CREATE TABLE "log" ------------------------------------------
CREATE TABLE `log`( 
    `created` Timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `int_id` Char( 16 ) NOT NULL,
    `str` Text NULL,
    `address` VarChar( 255 ) NULL );
-- CREATE INDEX "log_address_idx" ------------------------------
CREATE INDEX `log_address_idx` USING BTREE ON `log`( `address` );
-- -------------------------------------------------------------
