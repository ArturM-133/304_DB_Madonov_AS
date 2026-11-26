PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- Удаление таблиц в обратном порядке зависимостей
DROP TABLE IF EXISTS payroll;
DROP TABLE IF EXISTS work_orders;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS cars;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS employee_services;
DROP TABLE IF EXISTS service_prices;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS car_categories;
DROP TABLE IF EXISTS employees;

-- 1. Кадровый учёт работников
CREATE TABLE employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    position TEXT NOT NULL CHECK(position IN ('master', 'senior_master', 'receptionist')),
    phone TEXT NOT NULL,
    hire_date TEXT NOT NULL DEFAULT (date('now', 'localtime')),
    dismissal_date TEXT,  -- NULL = работает
    commission_percent REAL NOT NULL DEFAULT 30 CHECK(commission_percent >= 0 AND commission_percent <= 100)
);

-- 2. Категории автомобилей
CREATE TABLE car_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    coefficient REAL NOT NULL DEFAULT 1.0 CHECK(coefficient > 0)
);

-- 3. Справочник услуг
CREATE TABLE services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    duration_minutes INTEGER NOT NULL CHECK(duration_minutes > 0)
);

-- 4. Цена услуги по категории авто (связь М:М с атрибутом price)
CREATE TABLE service_prices (
    service_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    price REAL NOT NULL CHECK(price > 0),
    PRIMARY KEY (service_id, category_id),
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    FOREIGN KEY (category_id) REFERENCES car_categories(id) ON DELETE RESTRICT
);

-- 5. Специализация мастеров (какие услуги может выполнять)
CREATE TABLE employee_services (
    employee_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    PRIMARY KEY (employee_id, service_id),
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
);

-- 6. Клиенты
CREATE TABLE clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    email TEXT UNIQUE,
    registered_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- 7. Автомобили клиентов
CREATE TABLE cars (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    license_plate TEXT NOT NULL UNIQUE,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    FOREIGN KEY (category_id) REFERENCES car_categories(id) ON DELETE RESTRICT
);

-- 8. Предварительная запись
CREATE TABLE appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    car_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    scheduled_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK(status IN ('scheduled', 'completed', 'cancelled', 'no_show')),
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE RESTRICT,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT
);

-- 9. Фактически выполненные работы
CREATE TABLE work_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER NOT NULL UNIQUE,
    employee_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    car_id INTEGER NOT NULL,
    completed_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    revenue REAL NOT NULL CHECK(revenue >= 0),
    employee_share REAL NOT NULL CHECK(employee_share >= 0),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE RESTRICT,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE RESTRICT
);

-- 10. Расчёт зарплаты за период
CREATE TABLE payroll (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    total_revenue REAL NOT NULL CHECK(total_revenue >= 0),
    commission_percent REAL NOT NULL CHECK(commission_percent >= 0 AND commission_percent <= 100),
    salary_amount REAL NOT NULL CHECK(salary_amount >= 0),
    calculated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    UNIQUE(employee_id, period_start, period_end),
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT,
    CHECK(period_start < period_end)
);

-- Индексы для ускорения запросов
CREATE INDEX idx_employees_status ON employees(dismissal_date);
CREATE INDEX idx_appointments_employee ON appointments(employee_id, scheduled_at);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_work_orders_employee ON work_orders(employee_id, completed_at);

-- ТЕСТОВЫЕ ДАННЫЕ

-- Категории автомобилей
INSERT INTO car_categories (name, coefficient) VALUES
('Эконом', 1.0),
('Комфорт', 1.3),
('Бизнес', 1.6),
('Премиум', 2.0),
('Внедорожник', 1.8);

-- Услуги
INSERT INTO services (name, duration_minutes) VALUES
('Замена масла', 30),
('Замена фильтров', 20),
('Диагностика ходовой', 45),
('Ремонт тормозов', 120),
('Замена шин', 60),
('Развал-схождение', 90),
('Кузовной ремонт', 480),
('Покраска детали', 240),
('Замена аккумулятора', 15),
('Компьютерная диагностика', 60);

-- Цены услуг по категориям (service_prices)
INSERT INTO service_prices (service_id, category_id, price) VALUES
(1, 1, 2500), (1, 2, 3200), (1, 3, 4500), (1, 4, 6000), (1, 5, 5000),
(2, 1, 1200), (2, 2, 1500), (2, 3, 2000), (2, 4, 2800), (2, 5, 2300),
(3, 1, 1500), (3, 2, 1800), (3, 3, 2500), (3, 4, 3500), (3, 5, 3000),
(4, 1, 4000), (4, 2, 5000), (4, 3, 7000), (4, 4, 9500), (4, 5, 8000),
(5, 1, 1000), (5, 2, 1300), (5, 3, 1800), (5, 4, 2500), (5, 5, 2000),
(6, 1, 2200), (6, 2, 2800), (6, 3, 3500), (6, 4, 5000), (6, 5, 4200),
(7, 1, 15000), (7, 2, 20000), (7, 3, 30000), (7, 4, 50000), (7, 5, 40000),
(8, 1, 5000), (8, 2, 6500), (8, 3, 9000), (8, 4, 14000), (8, 5, 11000),
(9, 1, 800), (9, 2, 900), (9, 3, 1100), (9, 4, 1500), (9, 5, 1300),
(10, 1, 1800), (10, 2, 2200), (10, 3, 3000), (10, 4, 4500), (10, 5, 3800);

-- Мастера: 4 работают, 1 уволен (данные об их работе сохраняются!)
INSERT INTO employees (full_name, position, phone, hire_date, dismissal_date, commission_percent) VALUES
('Иванов Иван Иванович', 'master', '+79001112233', '2020-03-15', NULL, 25),
('Петров Пётр Петрович', 'senior_master', '+79002223344', '2018-01-10', NULL, 30),
('Сидоров Сергей Сергеевич', 'master', '+79003334455', '2021-06-01', NULL, 20),
('Кузнецов Кузьма Кузьмич', 'master', '+79004445566', '2019-09-01', '2023-12-31', 22),
('Смирнова Анна Петровна', 'receptionist', '+79005556677', '2022-02-14', NULL, 15);

-- Специализация мастеров
INSERT INTO employee_services (employee_id, service_id) VALUES
(1, 1), (1, 2), (1, 3), (1, 9), (1, 10),
(2, 3), (2, 4), (2, 6), (2, 7), (2, 8),
(3, 5), (3, 6), (3, 1), (3, 2),
(4, 4), (4, 7), (4, 8);

-- Клиенты
INSERT INTO clients (full_name, phone, email) VALUES
('Сорокин Алексей Викторович', '+79111234567', 'sorokin@mail.ru'),
('Волкова Мария Дмитриевна', '+79222345678', 'volkova.md@gmail.com'),
('Зайцев Николай Николаевич', '+79333456789', 'zaycev.nn@yandex.ru');

-- Автомобили клиентов
INSERT INTO cars (client_id, brand, model, license_plate, category_id) VALUES
(1, 'Toyota', 'Camry', 'А123ВС77', 3),
(2, 'Kia', 'Rio', 'Е456КХ99', 1),
(3, 'BMW', 'X5', 'М789ОР50', 5);

-- Предварительные записи
INSERT INTO appointments (client_id, car_id, service_id, employee_id, scheduled_at, status) VALUES
(1, 1, 1, 1, '2024-01-10 09:00:00', 'completed'),
(2, 2, 5, 3, '2024-01-10 11:00:00', 'completed'),
(3, 3, 7, 2, '2024-01-15 10:00:00', 'completed'),
(1, 1, 3, 1, '2024-01-20 14:00:00', 'scheduled'),
(2, 2, 10, 2, '2024-01-21 10:00:00', 'scheduled'),
(3, 3, 4, 4, '2023-11-05 09:00:00', 'completed');  -- работа уволенного мастера

-- Фактически выполненные работы
INSERT INTO work_orders (appointment_id, employee_id, service_id, car_id, completed_at, revenue, employee_share) VALUES
(1, 1, 1, 1, '2024-01-10 09:30:00', 4500, 1125),  
(2, 3, 5, 2, '2024-01-10 12:00:00', 1000, 200),    
(3, 2, 7, 3, '2024-01-15 18:00:00', 40000, 12000), 
(6, 4, 4, 3, '2023-11-05 11:00:00', 8000, 1760);   -- уволенный мастер

-- Расчёт зарплаты за январь 2024
INSERT INTO payroll (employee_id, period_start, period_end, total_revenue, commission_percent, salary_amount) VALUES
(1, '2024-01-01', '2024-01-31', 4500, 25, 1125),
(2, '2024-01-01', '2024-01-31', 40000, 30, 12000),
(3, '2024-01-01', '2024-01-31', 1000, 20, 200);

COMMIT;

-- Проверка: данные уволенного мастера сохранены
SELECT e.full_name, e.dismissal_date, COUNT(w.id) AS works_count, SUM(w.revenue) AS total_revenue
FROM employees e
LEFT JOIN work_orders w ON w.employee_id = e.id
GROUP BY e.id;