# Quantizied-8-bit-CNN-accelartor
Convolutional Neural Networks (CNNs) have gained
significant popularity in the field of Deep Learning (DL) due to
their efficiency in capturing local features from images and videos
in a manner that mimics the human cortex. These advantages
make CNNs useful in various vision applications, enabling them
to perform tasks such as environment perception, object identifi-
cation and detection, pattern recognition, and object tracking.
However, executing CNNs requires a substantial amount of
computing power and memory resources, necessitating a high-
performance desktop graphics processing unit (GPU), which is
not suitable for edge applications, such as autonomous vehicles,
mobile robots, and drones, which are limited in terms of power
and size. This article proposes a hardware FPGA accelerator
that supports quantized neural network (QNN) inference with
8-bit precision for both activations and weights. The accelerator
utilizes a unified data flow to execute both CNNs and Depth-
wise CNNs, supporting any arbitrary shapes of activation and
weights. The entire design is implemented on the Xilinx ZCU102
evaluation board, achieving peak performance of 143 Giga Op-
erations Per Second (GOPS) with power consumption of 4 watts.
The accelerator achieves a 2× speedup over the NVIDIA Jetson
TX2 when executing MobileNetV1 with an input size of 128×128,
resulting in a 43% reduction in total power consumption.
