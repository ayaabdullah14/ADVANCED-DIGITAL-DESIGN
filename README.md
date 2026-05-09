# 6-Bit Digital Comparator — Advanced Digital Design (ENCS3310)

![Language](https://img.shields.io/badge/Language-Verilog-6B21A8?style=for-the-badge&logoColor=white)
![Simulation](https://img.shields.io/badge/Simulation-ModelSim-0EA5E9?style=for-the-badge&logoColor=white)
![Test Cases](https://img.shields.io/badge/Test_Cases-8000_PASS_/_0_FAIL-22C55E?style=for-the-badge&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-success?style=for-the-badge)

A Verilog implementation of a 6-bit digital comparator supporting both **signed** and **unsigned** comparison modes. The design uses a modular architecture — registers, comparator logic, and a MUX — verified against a behavioral reference model across 8,000 randomized test cases.


---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Modules](#modules)
- [How It Works](#how-it-works)
- [Simulation & Testing](#simulation--testing)
- [Results](#results)
- [Future Work](#future-work)

---

## Overview

The comparator takes two 6-bit inputs **A** and **B** and produces three output signals:

| Output | Meaning |
|--------|---------|
| `A_eq_B` | A is equal to B |
| `A_gt_B` | A is greater than B |
| `A_lt_B` | A is less than B |

A `Selection` signal determines the comparison mode:

| Selection | Mode |
|-----------|------|
| `0` | Unsigned comparison |
| `1` | Signed (two's complement) comparison |

---

## Architecture

```
A[5:0] ──► Register_6bit ──► ┬──► SignedComparator  ──► ┐
                              │                           │
B[5:0] ──► Register_6bit ──► ┴──► Comparator (Unsigned) ─► MUX_2to1 ──► Register_3bit ──► OUTPUT[2:0]
                                                           │
Selection ─────────────────────────────────────────────────┘
```

**Block diagram (Fig. 1):** Inputs are latched into registers, passed to both signed and unsigned comparators in parallel, and the MUX selects the correct result based on `Selection`. The output is stored in a final output register.

---

## Modules

### 1. `Register_6bit` / `Register_3bit`
D flip-flop based registers triggered on the rising clock edge.

- **Purpose:** Synchronize inputs and outputs with the clock, preventing race conditions and propagation delay glitches.
- **Stores:** 6-bit input values (A, B) and 3-bit comparison outputs.

### 2. `Comparator` (Unsigned)
Compares two 6-bit values treating all bits as non-negative integers.

| Operation | Gate Logic |
|-----------|-----------|
| Equality (`A_eq_B`) | XNOR each bit pair → AND all results |
| Greater than (`A_gt_B`) | Bitwise comparison MSB → LSB with AND/OR gates |
| Less than (`A_lt_B`) | Inverse of greater-than logic with AND/OR gates |

### 3. `SignedComparator`
Compares two 6-bit values in two's complement representation.

- The **MSB (bit 5)** is treated as the sign bit.
- If signs differ → positive value is always greater.
- If signs match → comparison proceeds like unsigned.
- Uses NOT, AND, and OR gates with defined propagation delays.

### 4. `MUX_2to1`
A 2-to-1 multiplexer that routes either the signed or unsigned comparison result to the output.

```
Selection = 0  →  Output = Unsigned result
Selection = 1  →  Output = Signed result
```

---

## How It Works

```
1. A and B are loaded into 6-bit input registers on clock rising edge
2. Both Comparator (unsigned) and SignedComparator run in parallel
3. Each produces 3 signals: {Equal, Greater, Smaller}
4. MUX selects the result based on Selection signal
5. Output is stored in a 3-bit output register
6. Final OUTPUT[2:0] is driven from the output register
```

**Clock period:** 25 ns (optimal — determined through iterative timing analysis)
**Maximum operating frequency:** 20 MHz

---

## Simulation & Testing

The testbench (`test_project`) validates the design against a behavioral reference model (`Comparator_bahivoral`) using 8,000 randomized test cases.

### Test Setup

| Parameter | Value |
|-----------|-------|
| Test cases | 8,000 |
| Input A range | 0–63 (random 6-bit) |
| Input B range | 0–63 (random 6-bit) |
| Selection | Random 0 or 1 |
| Clock period | 25 ns (toggled every 25 time units) |
| Output settle delay | 150 ns |
| Pre-capture delay | 30 ns |

### Test Flow

```
for each test case (1 → 8000):
    randomize A, B, Selection
    wait 150ns  // outputs settle
    compare project outputs vs behavioral model outputs
    if match  → PASS
    if differs → FAIL (log mismatch details)

print summary: X PASS, Y FAIL / 8000
```

### Pass Case Output Format
```
Test Case 8000 - PASS: A = 000001, B = 001010, Selection = 1
    Project Module:    Equal = 0, Greater = 0, Smaller = 1
    Behavioral Module: Equal = 0, Greater = 0, Smaller = 1
------------------------------------------
```

### Fail Case Output Format
```
Test Case 7997 - FAIL: A = 010000, B = 111110, Selection = 1
    MISMATCH: Smaller_project = 0, Smaller_bahivoral = 1
------------------------------------------
```

---

## Results

### Correct Design
```
Random test cases completed.
Test Summary: 8000 PASS, 0 FAIL
```

### Intentional Error (parameter swap in SignedComparator instantiation)
Swapping `compare_signed[2]` ↔ `compare_signed[0]` in the module instantiation:
```
Test Summary: 5978 PASS, 2022 FAIL
```
This confirms the testbench correctly detects design errors.

---

## Clock Timing Analysis

| Clock Period | Result |
|-------------|--------|
| < 25 ns | Incorrect outputs — insufficient processing time |
| 25 ns | ✅ Optimal — reliable operation, no timing violations |
| > 40 ns | Synchronization issues — missed transitions, outdated outputs |

**Maximum frequency:** 20 MHz (determined by the longest stable clock period of 25 ns)

---

## Future Work

- **Flexible bit widths** — parameterize the design to support inputs beyond 6 bits
- **ALU integration** — combine with adders/multipliers to build a full Arithmetic Logic Unit
- **Error handling** — add parity bits, error-checking flags, and default output states for invalid inputs

---

> **Student:** Aya Abdullah (ID: 1220782) · Section 2
> **Course:** ENCS3310 Advanced Digital Design — Birzeit University
