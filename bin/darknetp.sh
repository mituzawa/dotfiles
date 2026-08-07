#darknetp classifier predict cfg/mnist.dataset cfg/mnist_lenet.cfg models/mnist/mnist_lenet.weights  data/mnist/images/t_00007_c3.png
#darknetp classifier predict -pp_start 9 -pp_end 9 cfg/mnist.dataset cfg/mnist_lenet.cfg models/mnist/mnist_lenet.weights  data/mnist/images/t_00007_c3.png
#darknetp classifier predict -pp_start 10 -pp_end 10 cfg/mnist.dataset cfg/mnist_lenet.cfg models/mnist/mnist_lenet.weights  data/mnist/images/t_00007_c3.png
#darknetp classifier predict -pp_start 9 -pp_end 10 cfg/mnist.dataset cfg/mnist_lenet.cfg models/mnist/mnist_lenet.weights  data/mnist/images/t_00007_c3.png
darknetp classifier predict -pp_start 8 -pp_end 8 cfg/mnist.dataset cfg/mnist_lenet.cfg models/mnist/mnist_lenet.weights data/mnist/images/t_00007_c3.png
