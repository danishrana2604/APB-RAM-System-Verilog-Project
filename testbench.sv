class transaction;
  
  typedef enum {write=0 ,read=1 ,random=2 ,error=3} oper_type;
  
  randc oper_type oper;
  rand bit [31:0] paddr;
  rand bit [31:0] pwdata;
  rand bit psel; //bit-2state : 0/1
  rand bit penable;
  rand bit pwrite;
  bit [31:0] prdata;
  bit pready;
  bit pslverr;
  
  constraint addr_c {
    paddr > 1; paddr < 5; //2,3,4
  }
  constraint data_c {
    pwdata > 1; pwdata < 10; //2-9
  }
  
  function void display(input string tag);
    $display("[%0s] OP : %0s paddr : %0d pwdata : %0d psel : %0b penable : %0b pwrite : %0b prdata : %0d pready : %0b pslverr : %0b", tag,oper.name(),paddr,pwdata,psel,penable,pwrite,prdata,pready,pslverr);
  endfunction
    
    function transaction copy();
      copy = new();
      copy.oper = this.oper;
      copy.paddr = this.paddr;
      copy.pwdata = this.pwdata;
      copy.psel = this.psel;
      copy.penable = this.penable;
      copy.pwrite = this.pwrite;
      copy.prdata = this.prdata;
      copy.pready = this.pready;
      copy.pslverr = this.pslverr;
    endfunction
endclass

/*module tb;
  transaction tr;
  
  initial begin
    tr = new();
    tr.display("TOP");
  end
endmodule

OUTPUT: [TOP] OP : write paddr : 0 pwdata : 0 psel : 0 penable : 0 pwrite : 0 prdata : 0 pready : 0 pslverr : 0 //default value of bit is 0
*/

class generator;
  
  transaction tr;
  mailbox #(transaction) mbx;
  int count = 0;
 
  event nextdrv; //driver completed task of triggering interface
  event nextsco; //sco completed comparision of data with ref/expected data
  event done;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    
    repeat(count) begin
      assert(tr.randomize()) else $error("Randomization failed");
      mbx.put(tr.copy); //sending deepcopy to driver
      tr.display("GEN");
      @(nextdrv);
      @(nextsco);
    end
    ->done;
  endtask
endclass

/*module tb;
  
  generator gen;
  mailbox #(transaction) mbx;
  
  initial begin
    mbx = new();
    gen = new(mbx);
    gen.count = 20;
    gen.run();
  end
endmodule

output : [GEN] OP : random paddr : 4 pwdata : 5 psel : 0 penable : 1 pwrite : 1 prdata : 0 pready : 0 pslverr : 0
*/

class driver;
  
  virtual apb_if vif;
  mailbox #(transaction) mbx;
  transaction datac; //data container
  event nextdrv;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task reset();
    vif.presetn <= 1'b0;
    vif.psel <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwdata <= 0;
    vif.paddr <= 0;
    vif.pwrite <= 1'b0;
    repeat(5) @(posedge vif.pclk);
    vif.presetn <= 1'b1;
    repeat(5) @(posedge vif.pclk);
    $display("[DRV] : RESET DONE");
  endtask
  
  task run();
    forever begin
      mbx.get(datac);
      
      if(datac.oper == 0) begin //write
      @(posedge vif.pclk);
        vif.psel <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwdata <= datac.pwdata;
        vif.paddr <= datac.paddr;
        vif.pwrite <= 1'b1;
    @(posedge vif.pclk);
        vif.penable <= 1'b1;
        repeat(2) @(posedge vif.pclk);
        vif.psel <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite <= 1'b0;
        $display("[DRV] : DATA Write op data : %0d and addr: %0d",datac.pwdata, datac.paddr);
      end
      
      else if (datac.oper == 1) begin //read
            @(posedge vif.pclk);
        vif.psel <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwdata <= datac.pwdata;
        vif.paddr <= datac.paddr;
        vif.pwrite <= 1'b0;
    @(posedge vif.pclk);
        vif.penable <= 1'b1;
        repeat(2) @(posedge vif.pclk);
        vif.psel <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite <= 1'b0;
           $display("[DRV] : DATA Read op addr: %0d", datac.paddr);
         end
         
         else if (datac.oper == 2) begin //random
            @(posedge vif.pclk);
        vif.psel <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwdata <= datac.pwdata;
        vif.paddr <= datac.paddr;
        vif.pwrite <= datac.pwrite;
    @(posedge vif.pclk);
        vif.penable <= 1'b1;
        repeat(2) @(posedge vif.pclk);
        vif.psel <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite <= 1'b0;
           $display("[DRV] : Random op");
         end
         
         else if (datac.oper == 3) begin //slv error
            @(posedge vif.pclk);
        vif.psel <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwdata <= datac.pwdata;
           vif.paddr <= $urandom_range(32,100);
        vif.pwrite <= datac.pwrite;
    @(posedge vif.pclk);
        vif.penable <= 1'b1;
        repeat(2) @(posedge vif.pclk);
        vif.psel <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite <= 1'b0;
           $display("[DRV] : SLV ERROR");
         end
         
         -> nextdrv;
    end
  endtask
endclass
         
 /*
module tb;
  generator gen;
  driver drv;
  mailbox #(transaction) mbx;
  event next;
  
  apb_if vif();
  apb_ram dut(vif.presetn, vif.pclk, vif.psel , vif.penable, vif.pwrite, vif.paddr, vif.pwdata, vif.prdata, vif.pready, vif.pslverr);
  
  initial begin
    vif.pclk <= 0;
  end
  
  always #10 vif.pclk <= ~vif.pclk; //nonblk as op for interface
  
  initial begin
    mbx = new();
    gen = new(mbx);
    gen.count = 20;
    
    drv = new(mbx);
    drv.vif = vif;
    
    gen.nextdrv = next;
    drv.nextdrv = next;
    
    fork
      gen.run();
      drv.run();
    join_none
    wait(gen.done.triggered);
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule

output : [GEN] OP : write paddr : 2 pwdata : 8 psel : 1 penable : 0 pwrite : 1 prdata : 0 pready : 0 pslverr : 0
[DRV] : DATA Write op data : 8 and addr: 2
*/

class monitor;
  virtual apb_if vif;
  mailbox #(transaction) mbx;
  transaction tr;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    tr = new();
    forever begin
      @(posedge vif.pclk);
      if((vif.psel) && (!vif.penable)) begin
        @(posedge vif.pclk);
        
        if(vif.psel && vif.pwrite && vif.penable) begin //write access
          @(posedge vif.pclk);
          tr.pwdata = vif.pwdata;
          tr.paddr = vif.paddr;
          tr.pwrite = vif.pwrite;
          tr.pslverr = vif.pslverr;
          $display("[MON] : DATA WRITE data: %0d addr: %0d write: %0b", vif.pwdata, vif.paddr, vif.pwrite);
          @(posedge vif.pclk); //to match with driver
        end //write accessed
        
        else if(vif.psel && !vif.pwrite && vif.penable) begin //read access
           @(posedge vif.pclk);
          tr.prdata = vif.prdata;
          tr.paddr = vif.paddr;
          tr.pwrite = vif.pwrite;
          tr.pslverr = vif.pslverr;
          $display("[MON] : DATA Read data: %0d addr: %0d write: %0b", vif.prdata, vif.paddr, vif.pwrite);
          @(posedge vif.pclk);
        end 
        
        mbx.put(tr);
      end
    end
  endtask
endclass

class scoreboard;
  
  mailbox #(transaction) mbx;
  transaction tr; //data container
  event nextsco;
  
  bit [31:0] pwdata[12] = '{default:0}; //declaring array
  bit [31:0] rdata;
  int index;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      $display("[SCO]: Data RCVD Wdata: %0d rdata: %0d addr: %0d write:%0b", tr.pwdata, tr.prdata, tr.paddr, tr.pwrite);
      
      if((tr.pwrite == 1'b1) && (tr.pslverr == 1'b0)) begin //write access
        pwdata[tr.paddr] = tr.pwdata;
        $display("[SCO] : DATA Stored data: %0d ADDR: %0d", tr.pwdata, tr.paddr);
      end
      
      else if((tr.pwrite == 1'b0) && (tr.pslverr == 1'b0)) begin //write access
        rdata = pwdata[tr.paddr];
        if( tr.prdata == rdata)
          $display("[SCO]: DATA MATCHED");
        else
          $display("[SCO]: DATA misMATCHED");
      end
      
      else if (tr.pslverr == 1'b1) begin
        $display("[SCO] : SLV error detected");
      end
      ->nextsco;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd; //gen -> drv
  event nextgs; //gen -> sco
  mailbox #(transaction) gdmbx; //gen-drv
  mailbox #(transaction) msmbx; //mon-sco
  
  virtual apb_if vif;
  
  function new(virtual apb_if vif);
    
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.nextdrv = nextgd;
    drv.nextdrv = nextgd;
    
    gen.nextsco = nextgs;
    sco.nextsco = nextgs;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
     gen.run();
     drv.run();
     mon.run();
     sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass
////////////////////
module tb;
  
  apb_if vif();
  apb_ram dut(vif.presetn, vif.pclk, vif.psel , vif.penable, vif.pwrite, vif.paddr, vif.pwdata, vif.prdata, vif.pready, vif.pslverr);
  
  initial begin
    vif.pclk <= 0;
  end
  
  always #10 vif.pclk <= ~vif.pclk; //nonblk as op for interface
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 30;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
  endmodule
