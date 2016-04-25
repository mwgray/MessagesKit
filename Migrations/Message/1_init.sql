
DROP TABLE IF EXISTS chat;

CREATE TABLE chat (
  id blob PRIMARY KEY NOT NULL,
  alias varchar,
  localAlias varchar,
  lastMessage blob,
  clarifiedCount integer,
  updatedCount integer,
  startedDate datetime,
  totalMessages integer,
  totalSent integer,
  customTitle varchar,
  activeMembers varchar,
  members varchar,
  _type integer
);

CREATE INDEX chat_lastMessage_idx ON chat (lastMessage);
CREATE INDEX chat_localAlias_idx ON chat (localAlias);
CREATE INDEX chat_alias_idx ON chat (alias);



DROP TABLE IF EXISTS message;

CREATE TABLE message (
  id blob PRIMARY KEY NOT NULL,
  chat blob,
  sender varchar,
  sent datetime,
  updated datetime,
  status integer,
  statusTimestamp datetime,
  flags integer,
  data1,
  data2,
  data3,
  data4,
  _type integer
);

CREATE INDEX message_status_idx ON message (status);
CREATE INDEX message_sent_desc_idx ON message (sent DESC);
CREATE INDEX message_sent_asc_idx ON message (sent ASC);
CREATE INDEX message_sender_idx ON message (sender);
CREATE INDEX message_chat_idx ON message (chat);
CREATE INDEX message_flags_idx ON message (flags);



DROP TABLE IF EXISTS notification;

CREATE TABLE notification (
  id blob PRIMARY KEY NOT NULL,
  chatId blob,
  data blob
);

CREATE INDEX notification_chat_idx ON notification (chatId);



DROP TABLE IF EXISTS blob;

CREATE TABLE blob (
  id integer PRIMARY KEY,
  data blob,
  refs integer
);
