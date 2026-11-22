-- Decisión del dueño sobre una suspendida con el periodo vencido: reanudar el
-- adeudo (se cobran los periodos que no pagó) u olvidarlo (se condona y
-- arranca un periodo nuevo hoy). Cada una deja su propio evento.
ALTER TYPE "MembershipEventType" ADD VALUE 'DEBT_RESUMED';
ALTER TYPE "MembershipEventType" ADD VALUE 'DEBT_FORGIVEN';
