/-
Copyright (c) 2019 Seul Baek. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Seul Baek

DNF transformation.
-/

import tactic.omega.clause
import tactic.omega.int.form

namespace omega
namespace int

local notation x ` =* ` y := form.eq x y
local notation x ` ≤* ` y := form.le x y
local notation `¬* ` p   := form.not p
local notation p ` ∨* ` q := form.or p q
local notation p ` ∧* ` q := form.and p q

@[simp] def push_neg : form → form
| (p ∨* q) := (push_neg p) ∧* (push_neg q)
| (p ∧* q) := (push_neg p) ∨* (push_neg q)
| (¬*p)    := p
| p        := ¬* p

lemma push_neg_equiv :
  ∀ {p : form}, form.equiv (push_neg p) (¬* p) :=
begin
  form.induce `[intros v; try {refl}],
  { simp only [classical.not_not, push_neg, form.holds] },
  { simp only [form.holds, push_neg, not_or_distrib, ihp v, ihq v] },
  { simp only [form.holds, push_neg, classical.not_and_distrib, ihp v, ihq v] }
end

def nnf : form → form
| (¬* p)   := push_neg (nnf p)
| (p ∨* q) := (nnf p) ∨* (nnf q)
| (p ∧* q) := (nnf p) ∧* (nnf q)
| a        := a

def is_nnf : form → Prop
| (t =* s) := true
| (t ≤* s) := true
| ¬*(t =* s) := true
| ¬*(t ≤* s) := true
| (p ∨* q) := is_nnf p ∧ is_nnf q
| (p ∧* q) := is_nnf p ∧ is_nnf q
| _ := false

lemma is_nnf_push_neg : ∀ p : form, is_nnf p → is_nnf (push_neg p) :=
begin
  form.induce `[intro h1; try {trivial}],
  { cases p; try {cases h1}; trivial },
  { cases h1, constructor; [{apply ihp}, {apply ihq}]; assumption },
  { cases h1, constructor; [{apply ihp}, {apply ihq}]; assumption }
end

def neg_free : form → Prop
| (t =* s) := true
| (t ≤* s) := true
| (p ∨* q) := neg_free p ∧ neg_free q
| (p ∧* q) := neg_free p ∧ neg_free q
| _        := false

lemma is_nnf_nnf : ∀ p : form, is_nnf (nnf p) :=
begin
  form.induce `[try {trivial}],
  { apply is_nnf_push_neg _ ih },
  { constructor; assumption },
  { constructor; assumption }
end

lemma nnf_equiv : ∀ {p : form}, form.equiv (nnf p) p :=
begin
  form.induce `[intros v; try {refl}; simp only [nnf]],
  { rw push_neg_equiv,
    apply not_iff_not_of_iff, apply ih },
  { apply pred_mono_2' (ihp v) (ihq v) },
  { apply pred_mono_2' (ihp v) (ihq v) }
end

@[simp] def neg_elim : form → form
| (¬* (t =* s)) := (t.add_one ≤* s) ∨* (s.add_one ≤* t)
| (¬* (t ≤* s)) := s.add_one ≤* t
| (p ∨* q) := (neg_elim p) ∨* (neg_elim q)
| (p ∧* q) := (neg_elim p) ∧* (neg_elim q)
| p        := p

lemma neg_free_neg_elim : ∀ p : form, is_nnf p → neg_free (neg_elim p) :=
begin
  form.induce `[intro h1, try {simp only [neg_free, neg_elim]}, try {trivial}],
  { cases p; try {cases h1}; try {trivial}, constructor; trivial },
  { cases h1, constructor; [{apply ihp}, {apply ihq}]; assumption },
  { cases h1, constructor; [{apply ihp}, {apply ihq}]; assumption }
end

lemma le_and_le_iff_eq {α : Type} [partial_order α] {a b : α} :
  (a ≤ b ∧ b ≤ a) ↔ a = b :=
begin
  constructor; intro h1,
  { cases h1, apply le_antisymm; assumption },
  { constructor; apply le_of_eq; rw h1  }
end

lemma implies_neg_elim : ∀ {p : form}, form.implies p (neg_elim p) :=
begin
  form.induce `[intros v h, try {apply h}],
  { cases p with t s t s; try {apply h},
    { simp only [le_and_le_iff_eq.symm,
        classical.not_and_distrib, not_le,
        preterm.val, form.holds] at h,
      simp only [int.add_one_le_iff, preterm.add_one,
        preterm.val, form.holds, neg_elim],
      rw or_comm, assumption },
    { simp only [not_le, int.add_one_le_iff,
        preterm.add_one, not_le, preterm.val,
        form.holds, neg_elim] at *,
      assumption} },
  { simp only [neg_elim], cases h; [{left, apply ihp},
    {right, apply ihq}]; assumption },
  { apply and.imp (ihp _) (ihq _) h }
end

@[simp] def dnf_core : form → list clause
| (p ∨* q) := (dnf_core p) ++ (dnf_core q)
| (p ∧* q) :=
  (list.product (dnf_core p) (dnf_core q)).map
  (λ pq, clause.append pq.fst pq.snd)
| (t =* s) := [([term.sub (canonize s) (canonize t)],[])]
| (t ≤* s) := [([],[term.sub (canonize s) (canonize t)])]
| (¬* _)   := []

def dnf (p : form) : list clause :=
dnf_core $ neg_elim $ nnf p

lemma exists_clause_holds {v : nat → int} :
  ∀ {p : form}, neg_free p → p.holds v → ∃ c ∈ (dnf_core p), clause.holds v c :=
begin
  form.induce `[intros h1 h2],
  { apply list.exists_mem_cons_of, constructor,
    { simp only [preterm.val, form.holds] at h2,
      rw [list.forall_mem_singleton],
      simp only [h2, omega.int.val_canonize,
        omega.term.val_sub, sub_self] },
    { apply list.forall_mem_nil } },
  { apply list.exists_mem_cons_of, constructor,
    { apply list.forall_mem_nil },
    { simp only [preterm.val, form.holds] at h2 ,
      rw [list.forall_mem_singleton],
      simp only [val_canonize,
        preterm.val, term.val_sub],
      rw [le_sub, sub_zero], assumption } },
    { cases h1 },
    { cases h2 with h2 h2;
      [ {cases (ihp h1.left h2) with c h3},
        {cases (ihq h1.right h2) with c h3}];
      cases h3 with h3 h4;
      refine ⟨c, list.mem_append.elim_right _, h4⟩;
      [left,right]; assumption },
    { rcases (ihp h1.left h2.left) with ⟨cp, hp1, hp2⟩,
      rcases (ihq h1.right h2.right) with ⟨cq, hq1, hq2⟩,
      refine ⟨clause.append cp cq, ⟨_, clause.holds_append hp2 hq2⟩⟩,
      simp only [dnf_core, list.mem_map],
      refine ⟨(cp,cq),⟨_,rfl⟩⟩,
      rw list.mem_product,
      constructor; assumption }
end

lemma clauses_sat_dnf_core {p : form} :
  neg_free p → p.sat → clauses.sat (dnf_core p) :=
begin
  intros h1 h2, cases h2 with v h2,
  rcases (exists_clause_holds h1 h2) with ⟨c,h3,h4⟩,
  refine ⟨c,h3,v,h4⟩
end

lemma unsat_of_clauses_unsat {p : form} :
clauses.unsat (dnf p) → p.unsat :=
begin
  intros h1 h2, apply h1,
  apply clauses_sat_dnf_core,
  apply neg_free_neg_elim _ (is_nnf_nnf _),
  apply form.sat_of_implies_of_sat implies_neg_elim,
  have hrw := exists_congr (@nnf_equiv p),
  apply hrw.elim_right h2
end

end int

end omega
