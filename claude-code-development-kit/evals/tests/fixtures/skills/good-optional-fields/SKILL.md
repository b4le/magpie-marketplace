---
name: good-optional-fields
description: A skill exercising all optional fields to verify schema accepts them correctly during validation
allowed-tools:
  - Read
  - Grep
  - Glob
version: 1.0.0
last_updated: "2026-03-01"
created: "2026-01-15"
author: Test Author
categories:
  - testing
  - validation
tags:
  - schema-test
  - optional-fields
dependencies:
  - authoring-skills
auto-invoke: false
user-invocable: true
disable-model-invocation: false
model: sonnet
context: fork
agent: general-purpose
argument-hint: "<query>"
---

This is a test skill exercising all optional frontmatter fields.

## Purpose

Verifies that the skill-frontmatter schema correctly validates all optional fields.

## Usage

This fixture is used by the test suite only.
