--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: locations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE locations (
    id integer NOT NULL,
    label_0 text,
    label_1 text,
    label_2 text,
    label_3 text,
    label_4 text,
    label_5 text,
    label_6 text,
    label_7 text,
    label_8 text,
    label_9 text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE locations_id_seq OWNED BY locations.id;


--
-- Name: locations_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE locations_posts (
    location_id integer NOT NULL,
    post_id integer NOT NULL
);


--
-- Name: occurrence_entries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE occurrence_entries (
    id integer NOT NULL,
    label text,
    post_id integer,
    at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: occurrence_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE occurrence_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: occurrence_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE occurrence_entries_id_seq OWNED BY occurrence_entries.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    document text,
    realm text,
    tags_vector tsvector,
    created_by integer,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    external_id text,
    canonical_path text,
    klass text
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: readmarks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE readmarks (
    id integer NOT NULL,
    location_id integer,
    post_id integer DEFAULT 0,
    owner integer,
    unread_count integer DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: readmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE readmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: readmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE readmarks_id_seq OWNED BY readmarks.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE locations ALTER COLUMN id SET DEFAULT nextval('locations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE occurrence_entries ALTER COLUMN id SET DEFAULT nextval('occurrence_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE readmarks ALTER COLUMN id SET DEFAULT nextval('readmarks_id_seq'::regclass);


--
-- Name: locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: occurrence_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY occurrence_entries
    ADD CONSTRAINT occurrence_entries_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: readmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY readmarks
    ADD CONSTRAINT readmarks_pkey PRIMARY KEY (id);


--
-- Name: index_locations_on_labels; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_locations_on_labels ON locations USING btree (label_0, label_1, label_2, label_3, label_4, label_5, label_6, label_7, label_8, label_9);


--
-- Name: index_locations_posts_on_location_id_and_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_locations_posts_on_location_id_and_post_id ON locations_posts USING btree (location_id, post_id);


--
-- Name: index_occurrence_entries_on_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_occurrence_entries_on_at ON occurrence_entries USING btree (at);


--
-- Name: index_occurrence_entries_on_post_id_and_label; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_occurrence_entries_on_post_id_and_label ON occurrence_entries USING btree (post_id, label);


--
-- Name: index_posts_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_created_at ON posts USING btree (created_at);


--
-- Name: index_posts_on_created_by; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_created_by ON posts USING btree (created_by);


--
-- Name: index_posts_on_deleted; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_deleted ON posts USING btree (deleted);


--
-- Name: index_posts_on_realm; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_realm ON posts USING btree (realm);


--
-- Name: index_posts_on_realm_and_external_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_on_realm_and_external_id ON posts USING btree (realm, external_id);


--
-- Name: index_posts_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_updated_at ON posts USING btree (updated_at);


--
-- Name: index_readmarks_on_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_readmarks_on_location_id ON readmarks USING btree (location_id);


--
-- Name: index_readmarks_on_owner; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_readmarks_on_owner ON readmarks USING btree (owner);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

