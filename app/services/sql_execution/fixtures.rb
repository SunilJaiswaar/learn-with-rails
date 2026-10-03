module SqlExecution
  # The dataset every SQL challenge queries.
  #
  # Deliberately small enough that a learner can reason about the expected
  # answer by hand, but shaped to support the whole SQL curriculum: joins,
  # grouping, subqueries, CTEs, window functions, ties, NULLs and date gaps.
  module Fixtures
    SCHEMA = "sql_sandbox".freeze

    # Order matters: children are created after the parents they reference.
    TABLES = %w[departments employees customers orders order_items events].freeze

    DDL = <<~SQL.freeze
      CREATE TABLE #{SCHEMA}.departments (
        id          integer PRIMARY KEY,
        name        text NOT NULL,
        budget      numeric(12, 2)
      );

      CREATE TABLE #{SCHEMA}.employees (
        id            integer PRIMARY KEY,
        name          text NOT NULL,
        department_id integer REFERENCES #{SCHEMA}.departments(id),
        manager_id    integer REFERENCES #{SCHEMA}.employees(id),
        salary        numeric(10, 2) NOT NULL,
        hired_on      date NOT NULL
      );

      CREATE TABLE #{SCHEMA}.customers (
        id       integer PRIMARY KEY,
        name     text NOT NULL,
        country  text
      );

      CREATE TABLE #{SCHEMA}.orders (
        id          integer PRIMARY KEY,
        customer_id integer REFERENCES #{SCHEMA}.customers(id),
        status      text NOT NULL,
        total       numeric(10, 2) NOT NULL,
        placed_on   date NOT NULL
      );

      -- Large enough (50k rows) that the planner genuinely chooses between a
      -- sequential scan and an index scan, which is what makes EXPLAIN
      -- teachable. `status` is deliberately left unindexed and low-cardinality
      -- so the contrast with the indexed `user_id` is visible.
      CREATE TABLE #{SCHEMA}.events (
        id          integer PRIMARY KEY,
        user_id     integer NOT NULL,
        status      text NOT NULL,
        occurred_on date NOT NULL
      );

      CREATE TABLE #{SCHEMA}.order_items (
        id         integer PRIMARY KEY,
        order_id   integer REFERENCES #{SCHEMA}.orders(id),
        product    text NOT NULL,
        quantity   integer NOT NULL,
        unit_price numeric(10, 2) NOT NULL
      );
    SQL

    # Notable properties the curriculum relies on:
    #   * Engineering has a two-way tie at the top salary (Priya and Wei, 95000)
    #   * Support has exactly one employee, and Logistics has none
    #   * Chen has no manager (NULL), so outer joins and IS NULL are meaningful
    #   * Order 1004 is 'cancelled', so status filters change the answer
    #   * Customer 4 (Dmitri) has never ordered
    #   * placed_on skips 2024-03-03, giving a gap for gaps-and-islands work
    DATA = <<~SQL.freeze
      INSERT INTO #{SCHEMA}.departments (id, name, budget) VALUES
        (1, 'Engineering', 1200000.00),
        (2, 'Sales',        640000.00),
        (3, 'Support',      180000.00),
        (4, 'Logistics',       NULL);

      INSERT INTO #{SCHEMA}.employees (id, name, department_id, manager_id, salary, hired_on) VALUES
        (1, 'Chen',   1, NULL, 120000.00, '2018-01-15'),
        (2, 'Priya',  1,    1,  95000.00, '2019-03-01'),
        (3, 'Wei',    1,    1,  95000.00, '2020-07-20'),
        (4, 'Aisha',  1,    1,  78000.00, '2021-09-06'),
        (5, 'Bruno',  2,    1,  82000.00, '2019-11-11'),
        (6, 'Dana',   2,    5,  67000.00, '2022-02-14'),
        (7, 'Emeka',  2,    5,  67000.00, '2022-06-30'),
        (8, 'Farida', 3,    1,  54000.00, '2023-04-03');

      INSERT INTO #{SCHEMA}.customers (id, name, country) VALUES
        (1, 'Acme Ltd',    'GB'),
        (2, 'Globex',      'US'),
        (3, 'Initech',     'US'),
        (4, 'Dmitri Co',   'DE');

      INSERT INTO #{SCHEMA}.orders (id, customer_id, status, total, placed_on) VALUES
        (1001, 1, 'paid',      250.00, '2024-03-01'),
        (1002, 1, 'paid',       90.00, '2024-03-02'),
        (1003, 2, 'paid',      400.00, '2024-03-02'),
        (1004, 2, 'cancelled', 999.00, '2024-03-04'),
        (1005, 3, 'paid',      120.00, '2024-03-05'),
        (1006, 1, 'pending',    60.00, '2024-03-05');

      INSERT INTO #{SCHEMA}.events (id, user_id, status, occurred_on)
      SELECT i,
             (i % 5000) + 1,
             CASE WHEN i % 10 = 0 THEN 'failed' ELSE 'ok' END,
             DATE '2024-01-01' + ((i % 365) || ' days')::interval
      FROM generate_series(1, 50000) AS i;

      -- Indexed on user_id only. Queries on status must scan.
      CREATE INDEX events_user_id_idx ON #{SCHEMA}.events (user_id);

      -- The planner needs statistics before it will choose the index.
      ANALYZE #{SCHEMA}.events;

      INSERT INTO #{SCHEMA}.order_items (id, order_id, product, quantity, unit_price) VALUES
        (1, 1001, 'bolt',   10, 15.00),
        (2, 1001, 'nut',    20,  5.00),
        (3, 1002, 'washer', 30,  3.00),
        (4, 1003, 'bolt',   16, 25.00),
        (5, 1005, 'nut',    24,  5.00),
        (6, 1006, 'bolt',    4, 15.00);
    SQL
  end
end
