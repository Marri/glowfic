SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: audits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.audits (
    id integer NOT NULL,
    auditable_id integer,
    auditable_type character varying,
    associated_id integer,
    associated_type character varying,
    user_id integer,
    user_type character varying,
    username character varying,
    action character varying,
    audited_changes text,
    version integer DEFAULT 0,
    comment character varying,
    remote_address character varying,
    created_at timestamp without time zone,
    request_uuid character varying
);


--
-- Name: audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audits_id_seq OWNED BY public.audits.id;


--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.blocks (
    id bigint NOT NULL,
    blocking_user_id integer NOT NULL,
    blocked_user_id integer NOT NULL,
    block_interactions boolean DEFAULT true,
    hide_them integer DEFAULT 0,
    hide_me integer DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: board_authors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.board_authors (
    id integer NOT NULL,
    user_id integer NOT NULL,
    board_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    cameo boolean DEFAULT false
);


--
-- Name: board_authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.board_authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: board_authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.board_authors_id_seq OWNED BY public.board_authors.id;


--
-- Name: board_sections; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.board_sections (
    id integer NOT NULL,
    board_id integer NOT NULL,
    name character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    section_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text
);


--
-- Name: board_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.board_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: board_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.board_sections_id_seq OWNED BY public.board_sections.id;


--
-- Name: board_views; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.board_views (
    id integer NOT NULL,
    board_id integer NOT NULL,
    user_id integer NOT NULL,
    ignored boolean DEFAULT false,
    notify_message boolean DEFAULT false,
    notify_email boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    read_at timestamp without time zone
);


--
-- Name: board_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.board_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: board_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.board_views_id_seq OWNED BY public.board_views.id;


--
-- Name: boards; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.boards (
    id integer NOT NULL,
    name public.citext NOT NULL,
    creator_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    pinned boolean DEFAULT false
);


--
-- Name: boards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.boards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: boards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.boards_id_seq OWNED BY public.boards.id;


--
-- Name: character_aliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.character_aliases (
    id integer NOT NULL,
    character_id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: character_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.character_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: character_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.character_aliases_id_seq OWNED BY public.character_aliases.id;


--
-- Name: character_groups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.character_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying NOT NULL
);


--
-- Name: character_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.character_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: character_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.character_groups_id_seq OWNED BY public.character_groups.id;


--
-- Name: character_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.character_tags (
    id integer NOT NULL,
    character_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: character_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.character_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: character_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.character_tags_id_seq OWNED BY public.character_tags.id;


--
-- Name: characters; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.characters (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name public.citext NOT NULL,
    template_name character varying,
    screenname character varying,
    template_id integer,
    default_icon_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    pb character varying,
    character_group_id integer,
    description text
);


--
-- Name: characters_galleries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.characters_galleries (
    id integer NOT NULL,
    character_id integer NOT NULL,
    gallery_id integer NOT NULL,
    section_order integer DEFAULT 0 NOT NULL,
    added_by_group boolean DEFAULT false
);


--
-- Name: characters_galleries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.characters_galleries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: characters_galleries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.characters_galleries_id_seq OWNED BY public.characters_galleries.id;


--
-- Name: characters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.characters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: characters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.characters_id_seq OWNED BY public.characters.id;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    favorite_id integer NOT NULL,
    favorite_type character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.favorites_id_seq OWNED BY public.favorites.id;


--
-- Name: flat_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.flat_posts (
    id integer NOT NULL,
    post_id integer NOT NULL,
    content text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: flat_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flat_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flat_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flat_posts_id_seq OWNED BY public.flat_posts.id;


--
-- Name: galleries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.galleries (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: galleries_icons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.galleries_icons (
    id integer NOT NULL,
    icon_id integer,
    gallery_id integer
);


--
-- Name: galleries_icons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.galleries_icons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: galleries_icons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.galleries_icons_id_seq OWNED BY public.galleries_icons.id;


--
-- Name: galleries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.galleries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: galleries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.galleries_id_seq OWNED BY public.galleries.id;


--
-- Name: gallery_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.gallery_tags (
    id integer NOT NULL,
    gallery_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: gallery_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gallery_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gallery_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gallery_tags_id_seq OWNED BY public.gallery_tags.id;


--
-- Name: icons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.icons (
    id integer NOT NULL,
    user_id integer NOT NULL,
    url character varying NOT NULL,
    keyword character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    credit character varying,
    has_gallery boolean DEFAULT false,
    s3_key character varying
);


--
-- Name: icons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.icons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: icons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.icons_id_seq OWNED BY public.icons.id;


--
-- Name: index_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.index_posts (
    id integer NOT NULL,
    post_id integer NOT NULL,
    index_id integer NOT NULL,
    index_section_id integer,
    description text,
    section_order integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: index_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.index_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: index_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.index_posts_id_seq OWNED BY public.index_posts.id;


--
-- Name: index_sections; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.index_sections (
    id integer NOT NULL,
    index_id integer NOT NULL,
    name public.citext NOT NULL,
    description text,
    section_order integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: index_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.index_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: index_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.index_sections_id_seq OWNED BY public.index_sections.id;


--
-- Name: indexes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.indexes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name public.citext NOT NULL,
    description text,
    privacy integer DEFAULT 0 NOT NULL,
    open_to_anyone boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: indexes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.indexes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.indexes_id_seq OWNED BY public.indexes.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    sender_id integer NOT NULL,
    recipient_id integer NOT NULL,
    parent_id integer,
    thread_id integer,
    subject character varying,
    message text,
    unread boolean DEFAULT true,
    visible_inbox boolean DEFAULT true,
    visible_outbox boolean DEFAULT true,
    marked_inbox boolean DEFAULT false,
    marked_outbox boolean DEFAULT false,
    read_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: news; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.news (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    content text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: news_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_id_seq OWNED BY public.news.id;


--
-- Name: news_views; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.news_views (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    news_id integer
);


--
-- Name: news_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_views_id_seq OWNED BY public.news_views.id;


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.password_resets (
    id integer NOT NULL,
    user_id integer NOT NULL,
    auth_token character varying NOT NULL,
    used boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: password_resets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_resets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_resets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_resets_id_seq OWNED BY public.password_resets.id;


--
-- Name: post_authors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.post_authors (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    can_owe boolean DEFAULT true,
    can_reply boolean DEFAULT true,
    joined boolean DEFAULT false,
    joined_at timestamp without time zone
);


--
-- Name: post_authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_authors_id_seq OWNED BY public.post_authors.id;


--
-- Name: post_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.post_tags (
    id integer NOT NULL,
    post_id integer NOT NULL,
    tag_id integer NOT NULL,
    suggested boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: post_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_tags_id_seq OWNED BY public.post_tags.id;


--
-- Name: post_viewers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.post_viewers (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: post_viewers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_viewers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_viewers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_viewers_id_seq OWNED BY public.post_viewers.id;


--
-- Name: post_views; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.post_views (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    ignored boolean DEFAULT false,
    notify_message boolean DEFAULT false,
    notify_email boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    read_at timestamp without time zone,
    warnings_hidden boolean DEFAULT false
);


--
-- Name: post_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_views_id_seq OWNED BY public.post_views.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    board_id integer NOT NULL,
    user_id integer NOT NULL,
    subject character varying NOT NULL,
    content text,
    character_id integer,
    icon_id integer,
    privacy integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    status integer DEFAULT 0,
    section_id integer,
    section_order integer,
    description character varying,
    last_user_id integer,
    last_reply_id integer,
    edited_at timestamp without time zone,
    tagged_at timestamp without time zone,
    authors_locked boolean DEFAULT false,
    character_alias_id integer
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: replies; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.replies (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text,
    character_id integer,
    icon_id integer,
    thread_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    character_alias_id integer,
    reply_order integer
);


--
-- Name: replies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.replies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.replies_id_seq OWNED BY public.replies.id;


--
-- Name: reply_drafts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.reply_drafts (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text,
    character_id integer,
    icon_id integer,
    thread_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    character_alias_id integer
);


--
-- Name: reply_drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reply_drafts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reply_drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reply_drafts_id_seq OWNED BY public.reply_drafts.id;


--
-- Name: report_views; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.report_views (
    id integer NOT NULL,
    user_id integer NOT NULL,
    read_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: report_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_views_id_seq OWNED BY public.report_views.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tag_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.tag_tags (
    id integer NOT NULL,
    tagged_id integer NOT NULL,
    tag_id integer NOT NULL,
    suggested boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: tag_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_tags_id_seq OWNED BY public.tag_tags.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name public.citext NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    type character varying,
    description text,
    owned boolean DEFAULT false
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.templates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name public.citext,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text
);


--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.templates_id_seq OWNED BY public.templates.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username public.citext NOT NULL,
    crypted character varying NOT NULL,
    avatar_id integer,
    active_character_id integer,
    per_page integer DEFAULT 25,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    timezone character varying,
    email public.citext,
    email_notifications boolean,
    icon_picker_grouping boolean DEFAULT true,
    moiety character varying,
    layout character varying,
    moiety_name character varying,
    default_view character varying,
    default_editor character varying DEFAULT 'rtf'::character varying,
    time_display character varying DEFAULT '%b %d, %Y %l:%M %p'::character varying,
    salt_uuid character varying,
    unread_opened boolean DEFAULT false,
    hide_hiatused_tags_owed boolean DEFAULT false,
    hide_warnings boolean DEFAULT false,
    visible_unread boolean DEFAULT false,
    show_user_in_switcher boolean DEFAULT true,
    ignore_unread_daily_report boolean DEFAULT false,
    favorite_notifications boolean DEFAULT true,
    default_character_split character varying DEFAULT 'template'::character varying,
    role_id integer,
    tos_version integer,
    deleted boolean DEFAULT false
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audits ALTER COLUMN id SET DEFAULT nextval('public.audits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.board_authors ALTER COLUMN id SET DEFAULT nextval('public.board_authors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.board_sections ALTER COLUMN id SET DEFAULT nextval('public.board_sections_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.board_views ALTER COLUMN id SET DEFAULT nextval('public.board_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boards ALTER COLUMN id SET DEFAULT nextval('public.boards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_aliases ALTER COLUMN id SET DEFAULT nextval('public.character_aliases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_groups ALTER COLUMN id SET DEFAULT nextval('public.character_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_tags ALTER COLUMN id SET DEFAULT nextval('public.character_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.characters ALTER COLUMN id SET DEFAULT nextval('public.characters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.characters_galleries ALTER COLUMN id SET DEFAULT nextval('public.characters_galleries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites ALTER COLUMN id SET DEFAULT nextval('public.favorites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flat_posts ALTER COLUMN id SET DEFAULT nextval('public.flat_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries ALTER COLUMN id SET DEFAULT nextval('public.galleries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries_icons ALTER COLUMN id SET DEFAULT nextval('public.galleries_icons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_tags ALTER COLUMN id SET DEFAULT nextval('public.gallery_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.icons ALTER COLUMN id SET DEFAULT nextval('public.icons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_posts ALTER COLUMN id SET DEFAULT nextval('public.index_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_sections ALTER COLUMN id SET DEFAULT nextval('public.index_sections_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indexes ALTER COLUMN id SET DEFAULT nextval('public.indexes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news ALTER COLUMN id SET DEFAULT nextval('public.news_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_views ALTER COLUMN id SET DEFAULT nextval('public.news_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_resets ALTER COLUMN id SET DEFAULT nextval('public.password_resets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_authors ALTER COLUMN id SET DEFAULT nextval('public.post_authors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags ALTER COLUMN id SET DEFAULT nextval('public.post_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_viewers ALTER COLUMN id SET DEFAULT nextval('public.post_viewers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_views ALTER COLUMN id SET DEFAULT nextval('public.post_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies ALTER COLUMN id SET DEFAULT nextval('public.replies_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_drafts ALTER COLUMN id SET DEFAULT nextval('public.reply_drafts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_views ALTER COLUMN id SET DEFAULT nextval('public.report_views_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_tags ALTER COLUMN id SET DEFAULT nextval('public.tag_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates ALTER COLUMN id SET DEFAULT nextval('public.templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.audits
    ADD CONSTRAINT audits_pkey PRIMARY KEY (id);


--
-- Name: blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: board_authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.board_authors
    ADD CONSTRAINT board_authors_pkey PRIMARY KEY (id);


--
-- Name: board_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.board_sections
    ADD CONSTRAINT board_sections_pkey PRIMARY KEY (id);


--
-- Name: board_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.board_views
    ADD CONSTRAINT board_views_pkey PRIMARY KEY (id);


--
-- Name: boards_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.boards
    ADD CONSTRAINT boards_pkey PRIMARY KEY (id);


--
-- Name: character_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.character_aliases
    ADD CONSTRAINT character_aliases_pkey PRIMARY KEY (id);


--
-- Name: character_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.character_groups
    ADD CONSTRAINT character_groups_pkey PRIMARY KEY (id);


--
-- Name: character_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.character_tags
    ADD CONSTRAINT character_tags_pkey PRIMARY KEY (id);


--
-- Name: characters_galleries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.characters_galleries
    ADD CONSTRAINT characters_galleries_pkey PRIMARY KEY (id);


--
-- Name: characters_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.characters
    ADD CONSTRAINT characters_pkey PRIMARY KEY (id);


--
-- Name: favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: flat_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.flat_posts
    ADD CONSTRAINT flat_posts_pkey PRIMARY KEY (id);


--
-- Name: galleries_icons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.galleries_icons
    ADD CONSTRAINT galleries_icons_pkey PRIMARY KEY (id);


--
-- Name: galleries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.galleries
    ADD CONSTRAINT galleries_pkey PRIMARY KEY (id);


--
-- Name: gallery_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.gallery_tags
    ADD CONSTRAINT gallery_tags_pkey PRIMARY KEY (id);


--
-- Name: icons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.icons
    ADD CONSTRAINT icons_pkey PRIMARY KEY (id);


--
-- Name: index_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.index_posts
    ADD CONSTRAINT index_posts_pkey PRIMARY KEY (id);


--
-- Name: index_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.index_sections
    ADD CONSTRAINT index_sections_pkey PRIMARY KEY (id);


--
-- Name: indexes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.indexes
    ADD CONSTRAINT indexes_pkey PRIMARY KEY (id);


--
-- Name: messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: news_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_pkey PRIMARY KEY (id);


--
-- Name: news_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.news_views
    ADD CONSTRAINT news_views_pkey PRIMARY KEY (id);


--
-- Name: password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: post_authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.post_authors
    ADD CONSTRAINT post_authors_pkey PRIMARY KEY (id);


--
-- Name: post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (id);


--
-- Name: post_viewers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.post_viewers
    ADD CONSTRAINT post_viewers_pkey PRIMARY KEY (id);


--
-- Name: post_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.post_views
    ADD CONSTRAINT post_views_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: replies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);


--
-- Name: reply_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.reply_drafts
    ADD CONSTRAINT reply_drafts_pkey PRIMARY KEY (id);


--
-- Name: report_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.report_views
    ADD CONSTRAINT report_views_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tag_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.tag_tags
    ADD CONSTRAINT tag_tags_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: associated_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX associated_index ON public.audits USING btree (associated_type, associated_id);


--
-- Name: auditable_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX auditable_index ON public.audits USING btree (auditable_type, auditable_id);


--
-- Name: idx_fts_post_content; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_fts_post_content ON public.posts USING gin (to_tsvector('english'::regconfig, COALESCE(content, ''::text)));


--
-- Name: idx_fts_post_subject; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_fts_post_subject ON public.posts USING gin (to_tsvector('english'::regconfig, COALESCE((subject)::text, ''::text)));


--
-- Name: idx_fts_reply_content; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_fts_reply_content ON public.replies USING gin (to_tsvector('english'::regconfig, COALESCE(content, ''::text)));


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_audits_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_audits_on_created_at ON public.audits USING btree (created_at);


--
-- Name: index_audits_on_request_uuid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_audits_on_request_uuid ON public.audits USING btree (request_uuid);


--
-- Name: index_blocks_on_blocked_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_blocks_on_blocked_user_id ON public.blocks USING btree (blocked_user_id);


--
-- Name: index_blocks_on_blocking_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_blocks_on_blocking_user_id ON public.blocks USING btree (blocking_user_id);


--
-- Name: index_board_authors_on_board_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_board_authors_on_board_id ON public.board_authors USING btree (board_id);


--
-- Name: index_board_authors_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_board_authors_on_user_id ON public.board_authors USING btree (user_id);


--
-- Name: index_board_views_on_user_id_and_board_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_board_views_on_user_id_and_board_id ON public.board_views USING btree (user_id, board_id);


--
-- Name: index_character_aliases_on_character_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_character_aliases_on_character_id ON public.character_aliases USING btree (character_id);


--
-- Name: index_character_tags_on_character_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_character_tags_on_character_id ON public.character_tags USING btree (character_id);


--
-- Name: index_character_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_character_tags_on_tag_id ON public.character_tags USING btree (tag_id);


--
-- Name: index_characters_galleries_on_character_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_characters_galleries_on_character_id ON public.characters_galleries USING btree (character_id);


--
-- Name: index_characters_galleries_on_gallery_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_characters_galleries_on_gallery_id ON public.characters_galleries USING btree (gallery_id);


--
-- Name: index_characters_on_character_group_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_characters_on_character_group_id ON public.characters USING btree (character_group_id);


--
-- Name: index_characters_on_template_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_characters_on_template_id ON public.characters USING btree (template_id);


--
-- Name: index_characters_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_characters_on_user_id ON public.characters USING btree (user_id);


--
-- Name: index_favorites_on_favorite_id_and_favorite_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_favorites_on_favorite_id_and_favorite_type ON public.favorites USING btree (favorite_id, favorite_type);


--
-- Name: index_favorites_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_favorites_on_user_id ON public.favorites USING btree (user_id);


--
-- Name: index_flat_posts_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_flat_posts_on_post_id ON public.flat_posts USING btree (post_id);


--
-- Name: index_galleries_icons_on_gallery_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_galleries_icons_on_gallery_id ON public.galleries_icons USING btree (gallery_id);


--
-- Name: index_galleries_icons_on_icon_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_galleries_icons_on_icon_id ON public.galleries_icons USING btree (icon_id);


--
-- Name: index_galleries_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_galleries_on_user_id ON public.galleries USING btree (user_id);


--
-- Name: index_gallery_tags_on_gallery_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_gallery_tags_on_gallery_id ON public.gallery_tags USING btree (gallery_id);


--
-- Name: index_gallery_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_gallery_tags_on_tag_id ON public.gallery_tags USING btree (tag_id);


--
-- Name: index_icons_on_has_gallery; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_icons_on_has_gallery ON public.icons USING btree (has_gallery);


--
-- Name: index_icons_on_keyword; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_icons_on_keyword ON public.icons USING btree (keyword);


--
-- Name: index_icons_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_icons_on_url ON public.icons USING btree (url);


--
-- Name: index_icons_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_icons_on_user_id ON public.icons USING btree (user_id);


--
-- Name: index_index_posts_on_index_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_index_posts_on_index_id ON public.index_posts USING btree (index_id);


--
-- Name: index_index_posts_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_index_posts_on_post_id ON public.index_posts USING btree (post_id);


--
-- Name: index_index_sections_on_index_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_index_sections_on_index_id ON public.index_sections USING btree (index_id);


--
-- Name: index_indexes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_indexes_on_user_id ON public.indexes USING btree (user_id);


--
-- Name: index_messages_on_recipient_id_and_unread; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_messages_on_recipient_id_and_unread ON public.messages USING btree (recipient_id, unread);


--
-- Name: index_messages_on_sender_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_messages_on_sender_id ON public.messages USING btree (sender_id);


--
-- Name: index_messages_on_thread_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_messages_on_thread_id ON public.messages USING btree (thread_id);


--
-- Name: index_news_views_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_news_views_on_user_id ON public.news_views USING btree (user_id);


--
-- Name: index_password_resets_on_auth_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_password_resets_on_auth_token ON public.password_resets USING btree (auth_token);


--
-- Name: index_password_resets_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_password_resets_on_user_id_and_created_at ON public.password_resets USING btree (user_id, created_at);


--
-- Name: index_post_authors_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_authors_on_post_id ON public.post_authors USING btree (post_id);


--
-- Name: index_post_authors_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_authors_on_user_id ON public.post_authors USING btree (user_id);


--
-- Name: index_post_tags_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_tags_on_post_id ON public.post_tags USING btree (post_id);


--
-- Name: index_post_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_tags_on_tag_id ON public.post_tags USING btree (tag_id);


--
-- Name: index_post_viewers_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_viewers_on_post_id ON public.post_viewers USING btree (post_id);


--
-- Name: index_post_views_on_user_id_and_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_post_views_on_user_id_and_post_id ON public.post_views USING btree (user_id, post_id);


--
-- Name: index_posts_on_board_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_board_id ON public.posts USING btree (board_id);


--
-- Name: index_posts_on_character_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_character_id ON public.posts USING btree (character_id);


--
-- Name: index_posts_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_created_at ON public.posts USING btree (created_at);


--
-- Name: index_posts_on_icon_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_icon_id ON public.posts USING btree (icon_id);


--
-- Name: index_posts_on_tagged_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_tagged_at ON public.posts USING btree (tagged_at);


--
-- Name: index_posts_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_user_id ON public.posts USING btree (user_id);


--
-- Name: index_replies_on_character_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_character_id ON public.replies USING btree (character_id);


--
-- Name: index_replies_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_created_at ON public.replies USING btree (created_at);


--
-- Name: index_replies_on_icon_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_icon_id ON public.replies USING btree (icon_id);


--
-- Name: index_replies_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_post_id ON public.replies USING btree (post_id);


--
-- Name: index_replies_on_reply_order; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_reply_order ON public.replies USING btree (reply_order);


--
-- Name: index_replies_on_thread_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_thread_id ON public.replies USING btree (thread_id);


--
-- Name: index_replies_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_replies_on_user_id ON public.replies USING btree (user_id);


--
-- Name: index_reply_drafts_on_post_id_and_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_reply_drafts_on_post_id_and_user_id ON public.reply_drafts USING btree (post_id, user_id);


--
-- Name: index_report_views_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_report_views_on_user_id ON public.report_views USING btree (user_id);


--
-- Name: index_tag_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_tags_on_tag_id ON public.tag_tags USING btree (tag_id);


--
-- Name: index_tag_tags_on_tagged_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_tags_on_tagged_id ON public.tag_tags USING btree (tagged_id);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_tags_on_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tags_on_type ON public.tags USING btree (type);


--
-- Name: index_templates_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_templates_on_user_id ON public.templates USING btree (user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: user_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX user_index ON public.audits USING btree (user_id, user_type);


--
-- Name: fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO "schema_migrations" (version) VALUES
('20150413062555'),
('20150413233206'),
('20150414195302'),
('20150414195307'),
('20150414200044'),
('20150414211752'),
('20150415221435'),
('20150415221456'),
('20150417214406'),
('20150624201245'),
('20150704060600'),
('20151125201254'),
('20151127033352'),
('20151127181237'),
('20151127183038'),
('20151127210938'),
('20151130050434'),
('20151215041641'),
('20160108230631'),
('20160218041741'),
('20160218041751'),
('20160222042730'),
('20160223065123'),
('20160303032220'),
('20160306053517'),
('20160318021845'),
('20160322032647'),
('20160326210104'),
('20160410024710'),
('20160410060405'),
('20160410170309'),
('20160412035353'),
('20160416031844'),
('20160429033350'),
('20160604181644'),
('20160615094301'),
('20160627210836'),
('20160702213101'),
('20160704224416'),
('20160716055457'),
('20160719012330'),
('20160723172304'),
('20160731040017'),
('20160813025151'),
('20160827161416'),
('20160925032329'),
('20161008224853'),
('20161024185615'),
('20161107014948'),
('20161110055637'),
('20161126195558'),
('20161129195022'),
('20161218194918'),
('20170103184309'),
('20170109000120'),
('20170210013443'),
('20170221171959'),
('20170331133925'),
('20170413195840'),
('20170501214439'),
('20170505173455'),
('20170513052413'),
('20170519123223'),
('20170612015922'),
('20170617180015'),
('20170619010707'),
('20170814042150'),
('20170819222420'),
('20170821210336'),
('20170826211901'),
('20170828144608'),
('20170907180029'),
('20170911235423'),
('20170914191425'),
('20171001035221'),
('20171027225408'),
('20171104140915'),
('20171109031527'),
('20171111163658'),
('20171114013113'),
('20171127031443'),
('20171227030824'),
('20180109003825'),
('20180509172128'),
('20180928230642'),
('20181113044923'),
('20181127010456'),
('20190122034907'),
('20190331223926'),
('20190519223613'),
('20190802051248');


