# 🖼️ FPGA Line Buffer Image Scaler

<div align="center">

![Language](https://img.shields.io/badge/Language-Verilog_HDL-007ACC?style=for-the-badge&logo=verilog&logoColor=white)
![Tool](https://img.shields.io/badge/Tool-Vivado-FF5252?style=for-the-badge&logo=xilinx&logoColor=white)
![Algorithm](https://img.shields.io/badge/Algorithm-Bilinear_Interpolation-blue?style=for-the-badge)
![Hardware](https://img.shields.io/badge/H%2FW-Line_Buffer_Architecture-orange?style=for-the-badge)

<br>

> **Memory-Efficient Real-time Image Scaling Hardware Design**
>
> 외부 메모리(DDR) 없이 FPGA 내부의 라인 버퍼(BRAM)만을 활용하여 스트림 데이터를 실시간으로 확대/축소하는 하드웨어 가속기

</div>

---

## 📖 1. 프로젝트 개요 (Overview)

이 프로젝트는 **FPGA** 상에서 입력되는 영상 스트림을 실시간으로 스케일링(Scaling, 해상도 변환)하는 하드웨어 설계입니다.
이미지 처리에서 스케일링을 수행하려면 수직 방향의 픽셀 데이터가 필요하기 때문에, 일반적으로 프레임 버퍼를 사용합니다. 하지만 이 프로젝트는 **라인 버퍼(Line Buffer)** 아키텍처를 도입하여 전체 프레임을 저장하지 않고도 **적은 메모리 자원(BRAM)으로 고속 연산**을 수행하는 데 중점을 두었습니다.

### ✨ 핵심 설계 특징 (Key Features)
* **Line Buffer Architecture:** FIFO 또는 BRAM을 활용하여 N개의 행(Row) 데이터를 임시 저장, 윈도우(Window) 단위의 연산 환경 제공.
* **Real-time Processing:** 픽셀 클럭에 동기화되어 입력되는 픽셀을 지연 없이 처리하는 파이프라인(Pipeline) 구조.
* **Interpolation Logic:**
    * **Nearest Neighbor:** 가장 가까운 픽셀 값을 가져오는 단순 확대 방식.
    * **Bilinear Interpolation:** 인접한 4개의 픽셀($2 \times 2$)에 가중치를 적용하여 부드러운 이미지를 생성하는 선형 보간법 구현.
* **Resource Optimization:** 외부 메모리 인터페이스(DDR)를 제거하여 시스템 복잡도와 전력 소모 최소화.

---

## 🏗️ 2. 하드웨어 아키텍처 (H/W Architecture)

### 2.1 System Block Diagram
입력되는 픽셀 데이터는 라인 버퍼에 순차적으로 저장되며, 스케일러 로직은 버퍼에서 필요한 픽셀 윈도우를 추출하여 보간 연산을 수행합니다.

```mermaid
graph LR
    Input[Video Input Stream] --> LB[Line Buffer Controller]
    
    subgraph "Line Buffer Memory (BRAM)"
        LB -->|Write Line 0| RAM0[Row Buffer 0]
        LB -->|Write Line 1| RAM1[Row Buffer 1]
        RAM0 -->|Read Window| CALC
        RAM1 -->|Read Window| CALC
    end
    
    subgraph "Scaling Engine"
        CALC[Interpolation Logic] -->|Horizontal| X_CALC[X-Scale]
        X_CALC -->|Vertical| Y_CALC[Y-Scale]
    end
    
    Y_CALC --> Output[Resized Video Output]
````

### 2.2 Line Buffer Mechanism

스케일링(특히 Bilinear)을 위해서는 현재 픽셀의 위/아래 데이터가 동시에 필요합니다. 이를 위해 **Shift Register** 혹은 **Dual-port RAM**을 사용하여 데이터 흐름을 제어합니다.

  * **Write Operation:** 들어오는 픽셀을 현재 라인 버퍼에 씀.
  * **Read Operation:** 이전 라인 버퍼와 현재 라인 버퍼에서 동시에 데이터를 읽어 $2 \times 2$ 픽셀 매트릭스 형성.
  * **Coordinate Calculation:** 출력 해상도 좌표를 입력 해상도 좌표로 매핑(Inverse Mapping)하여 보간 계수($dx, dy$) 계산.

-----

## 📂 3. 프로젝트 발표 자료 (Presentation)

라인 버퍼 설계 원리, 보간 수식의 하드웨어 구현 방법 및 시뮬레이션 결과는 아래 보고서를 통해 확인하실 수 있습니다.

[![PDF Report](https://img.shields.io/badge/📄_PDF_Report-View_Document-FF0000?style=for-the-badge&logo=adobeacrobatreader&logoColor=white)](https://github.com/seokhyun-hwang/files/blob/main/LineBuffer_Scaler.pdf)

<br>

-----

## 📂 4. 폴더 구조 (Directory Structure)

```bash
📦 LineBuffer_Scaler
 ├── 📂 src                    # RTL Source Codes
 │   ├── 📜 scaler_top.v       # [Top] Scaler Module Wrapper
 │   ├── 📜 line_buffer.v      # Line Memory Controller (FIFO/BRAM)
 │   ├── 📜 bilinear_core.v    # Bilinear Interpolation Arithmetic Logic
 │   ├── 📜 coord_gen.v        # Coordinate Mapping Logic
 │   └── 📜 sync_gen.v         # Video Timing Generator (H/V Sync)
 ├── 📂 sim                    # Simulation Files
 │   ├── 📜 tb_scaler.v        # Testbench for Scaler Verification
 │   └── 📜 image_data.hex     # Test Input Image Data
 ├── 📂 docs                   # Documents
 │   └── 📜 LineBuffer_Scaler.pdf
 └── 📜 README.md
```

-----

## 🚀 5. 시뮬레이션 및 검증 (Simulation)

이 모듈은 이미지 데이터를 Hex 파일로 변환하여 Testbench에 인가하는 방식으로 검증되었습니다.

1.  **Image to Hex:** Python 스크립트 등을 이용해 원본 이미지를 텍스트(Hex) 데이터로 변환.
2.  **Run Simulation:** Vivado Simulator에서 `tb_scaler.v` 실행.
3.  **Output Analysis:** 시뮬레이션 결과로 출력된 텍스트 데이터를 다시 이미지로 변환하여 리사이징 품질(Quality) 확인.

> **Verification Point:** 라인 버퍼의 Read/Write 타이밍이 어긋나지 않는지, 보간된 픽셀 값이 소프트웨어(Matlab/Python) 결과와 일치하는지 확인.

-----

Copyright ⓒ 2025. SEOKHYUN HWANG. All rights reserved.

```
```
