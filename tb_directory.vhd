library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.logpack.all;

ENTITY tb_directory IS
END tb_directory;

ARCHITECTURE behavior OF tb_directory IS

	-- Component Declaration for the Unit Under Test (UUT)
	component llc_memory
		generic(DATA_WIDTH : natural := 8;
			    ADDR_WIDTH : natural := 6);
		port(clk   : in  std_logic;
			 raddr : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
			 waddr : in  natural range 0 to 2 ** ADDR_WIDTH - 1;
			 data  : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
			 we    : in  std_logic := '1';
			 q     : out std_logic_vector(DATA_WIDTH - 1 downto 0));
	end component llc_memory;

	component directory_manager
		generic(DIRECTORY_ID   : natural := 0;
			    DIRECTORIES_N  : natural := 4;
			    DATA_WIDTH     : natural := 32;
			    BLOCK_WIDTH    : natural := 16;
			    FIFO_REQ_WIDTH : natural := 8);
		Port(
			clk            : in  std_logic;
			reset          : in  std_logic;
			enable         : in  std_logic;

			-- Cache Controller Interface
			CCValidIn      : in  std_logic; -- Core valid signal, high if there is a valid request from the core
			CCGetPutIn     : in  Std_logic; -- Cache Controller operation (put or get)
			CCAddrIn       : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0); -- Request from the core (load and store) 
			CCDataIn       : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of store)
			CCValidOut     : out std_logic; -- Core valid out, if high there is a valid response for the core 
			CCAckOut       : out std_logic;
			CCAddrOut      : out std_logic_vector(BLOCK_WIDTH - 1 downto 0); -- Response for the core
			CCDataOut      : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of load)

			-- Router Interface
			RouterValidIn  : in  std_logic;
			RouterDataIn   : in  std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + 2 - 1 downto 0); -- 2 are the possible message type (Fwd-Get-M and Fwd-Get-S)
			RouterValidOut : out std_logic;
			RouterDataOut  : out std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + 2 - 1 downto 0);

			-- Memory interface
			MemDataIn      : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			MemReadAddr    : out std_logic_vector(BLOCK_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
			MemWriteEn     : out std_logic;
			MemWriteAddr   : out std_logic_vector(BLOCK_WIDTH - f_log2(DIRECTORIES_N) - 1 downto 0);
			MemDataOut     : out std_logic_vector(DATA_WIDTH - 1 downto 0)
		);
	end component directory_manager;

	constant DATA_WIDTH    : natural := 8;
	constant BLOCK_WIDTH   : natural := 8;
	constant CACHE_WIDTH   : natural := 4;
	constant DIRECTORIES_N : natural := 4;

	constant ADDR_WIDTH : natural := BLOCK_WIDTH - f_log2(DIRECTORIES_N);

	constant DIRECTORY_ID   : natural := 0;
	constant FIFO_REQ_WIDTH : natural := 8;

	-- Inputs LLC
	signal clk, reset, enable : std_logic                                   := '0';
	signal raddr, raddr_temp  : natural range 0 to 2 ** ADDR_WIDTH - 1      := 0;
	signal waddr, waddr_temp  : natural range 0 to 2 ** ADDR_WIDTH - 1      := 0;
	signal data, data_temp    : std_logic_vector((DATA_WIDTH - 1) downto 0) := (others => '0');
	signal we, we_temp        : std_logic                                   := '1';
	signal q                  : std_logic_vector(DATA_WIDTH - 1 downto 0)   := (others => '0');

	-- Input Directory
	signal CCValidIn      : std_logic                                                              := '0';
	signal CCGetPutIn     : Std_logic                                                              := '0';
	signal CCAddrIn       : std_logic_vector(BLOCK_WIDTH - 1 downto 0)                             := (others => '0');
	signal CCDataIn       : std_logic_vector(DATA_WIDTH - 1 downto 0)                              := (others => '0');
	signal CCValidOut     : std_logic                                                              := '0';
	signal CCAckOut       : std_logic                                                              := '0';
	signal CCAddrOut      : std_logic_vector(BLOCK_WIDTH - 1 downto 0)                             := (others => '0');
	signal CCDataOut      : std_logic_vector(DATA_WIDTH - 1 downto 0)                              := (others => '0');
	signal RouterValidIn  : std_logic                                                              := '0';
	signal RouterDataIn   : std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal RouterValidOut : std_logic                                                              := '0';
	signal RouterDataOut  : std_logic_vector(f_log2(DIRECTORIES_N) + BLOCK_WIDTH + 2 - 1 downto 0) := (others => '0');
	signal MemDataIn      : std_logic_vector(DATA_WIDTH - 1 downto 0)                              := (others => '0');
	signal MemReadAddr    : std_logic_vector(ADDR_WIDTH - 1 downto 0)                             := (others => '0');
	signal MemWriteEn     : std_logic                                                              := '0';
	signal MemWriteAddr   : std_logic_vector(ADDR_WIDTH - 1 downto 0)                             := (others => '0');
	signal MemDataOut     : std_logic_vector(DATA_WIDTH - 1 downto 0)                              := (others => '0');

	-- Clock period definitions
	constant clk_period : time := 10 ns;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut_llc : llc_memory
		generic map(
			DATA_WIDTH => DATA_WIDTH,
			ADDR_WIDTH => ADDR_WIDTH
		)
		port map(
			clk   => clk,
			raddr => raddr_temp,
			waddr => waddr_temp,
			data  => MemDataOut,
			we    => MemWriteEn,
			q     => MemDataIn
		);
		
	raddr_temp <= CONV_INTEGER(MemReadAddr);
	waddr_temp <= CONV_INTEGER(MemWriteAddr);

	uut_directory : directory_manager
		generic map(
			DIRECTORY_ID   => DIRECTORY_ID,
			DIRECTORIES_N  => DIRECTORIES_N,
			DATA_WIDTH     => DATA_WIDTH,
			BLOCK_WIDTH    => BLOCK_WIDTH,
			FIFO_REQ_WIDTH => FIFO_REQ_WIDTH
		)
		port map(
			clk            => clk,
			reset          => reset,
			enable         => enable,
			CCValidIn      => CCValidIn,
			CCGetPutIn     => CCGetPutIn,
			CCAddrIn       => CCAddrIn,
			CCDataIn       => CCDataIn,
			CCValidOut     => CCValidOut,
			CCAckOut       => CCAckOut,
			CCAddrOut      => CCAddrOut,
			CCDataOut      => CCDataOut,
			RouterValidIn  => RouterValidIn,
			RouterDataIn   => RouterDataIn,
			RouterValidOut => RouterValidOut,
			RouterDataOut  => RouterDataOut,
			MemDataIn      => MemDataIn,
			MemReadAddr    => MemReadAddr,
			MemWriteEn     => MemWriteEn,
			MemWriteAddr   => MemWriteAddr,
			MemDataOut     => MemDataOut
		);

	-- Clock process definitions
	clk_process : process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process;

	-- Stimulus process
	stim_proc : process
	begin
		-- hold reset state for 100 ns.
		reset <= '1';

		wait for 100 ns;
		enable <= '1';
		reset      <= '0';
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"00";
		CCDataIn <= x"11";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		
		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"F1";
		CCDataIn <= x"22";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		
		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"01";
		CCDataIn <= x"22";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		
		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"02";
		CCDataIn <= x"33";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		
		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"03";
		CCDataIn <= x"44";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		
		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '1';
		CCAddrIn   <= x"04";
		CCDataIn <= x"55";
		
		wait for clk_period;
		CCValidIn <= '0';
		CCGetPutIn <= '0';
		

		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '0';
		CCAddrIn   <= x"00";

		wait for clk_period;
		CCValidIn <= '0';

		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '0';
		CCAddrIn   <= x"03";

		wait for clk_period;
		CCValidIn <= '0';

		wait for clk_period * 10;
		CCValidIn  <= '1';
		CCGetPutIn <= '0';
		CCAddrIn   <= x"F3";

		wait for clk_period;
		CCValidIn <= '0';
		
		wait;

	end process;

END;