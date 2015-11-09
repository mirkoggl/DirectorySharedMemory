library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.logpack.all;

ENTITY tb_cache_controller IS
END tb_cache_controller;

ARCHITECTURE behavior OF tb_cache_controller IS
	component cache_controller
		generic(DIRECTORIES_N  : natural := 4;
			    DATA_WIDTH     : natural := 32;
			    BLOCK_WIDTH    : natural := 16;
			    CACHE_WIDTH    : natural := 4;
			    FIFO_REQ_WIDTH : natural := 8);
		port(clk               : in  std_logic;
			 reset             : in  std_logic;
			 enable            : in  std_logic;
			 CoreValidIn       : in  std_logic;
			 CoreLoadStore     : in  std_logic;
			 CoreAddrIn        : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0);
			 CoreDataIn        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			 CoreValidOut      : out std_logic;
			 CoreAck           : out std_logic;
			 CoreDataOut       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
			 DirectoryValidIn  : in  std_logic;
			 DirectoryValidOut : out std_logic;
			 CacheDataIn       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			 CacheHit          : in  std_logic;
			 CacheOp           : out std_logic_vector(1 downto 0);
			 CacheAddr         : out std_logic_vector(BLOCK_WIDTH - 1 downto 0);
			 CacheDataOut      : out std_logic_vector(DATA_WIDTH - 1 downto 0));
	end component cache_controller;

	-- Component Declaration for the Unit Under Test (UUT)
	component cache_memory
		generic(DATA_WIDTH  : natural := 32;
			    BLOCK_WIDTH : natural := 16;
			    CACHE_WIDTH : natural := 4);
		port(clk   : in  std_logic;
			 reset : in  std_logic;
			 addr  : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0);
			 op    : in  std_logic_vector(1 downto 0);
			 data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			 hit   : out std_logic;
			 q     : out std_logic_vector(DATA_WIDTH - 1 downto 0));
	end component cache_memory;

	constant DIRECTORIES_N  : natural := 4;
	constant CACHE_WIDTH    : natural := 4;
	constant FIFO_REQ_WIDTH : natural := 8;
	constant DATA_WIDTH     : natural := 8;
	constant BLOCK_WIDTH    : natural := 16;

	--Inputs cache
	signal clk, reset, enable : std_logic                                  := '0';
	signal addr, addr_temp    : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal op, op_temp        : std_logic_vector(1 downto 0);
	signal data, data_temp    : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal hit                : std_logic;
	signal q, q_temp          : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');

	-- Input controller
	signal CoreValidIn       : std_logic                                  := '0';
	signal CoreLoadStore     : std_logic                                  := '0';
	signal CoreAddrIn        : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal CoreDataIn        : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal CoreValidOut      : std_logic                                  := '0';
	signal CoreAck           : std_logic                                  := '0';
	signal CoreDataOut       : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal DirectoryValidIn  : std_logic                                  := '0';
	signal DirectoryValidOut : std_logic                                  := '0';
	signal CacheDataIn       : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal CacheHit          : std_logic                                  := '0';
	signal CacheOp           : std_logic_vector(1 downto 0)               := (others => '1');
	signal CacheAddr         : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal CacheDataOut      : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');

	-- Clock period definitions
	constant clk_period : time := 10 ns;

BEGIN
	uut_controller : cache_controller
		generic map(
			DIRECTORIES_N  => DIRECTORIES_N,
			DATA_WIDTH     => DATA_WIDTH,
			BLOCK_WIDTH    => BLOCK_WIDTH,
			CACHE_WIDTH    => CACHE_WIDTH,
			FIFO_REQ_WIDTH => FIFO_REQ_WIDTH
		)
		port map(
			clk               => clk,
			reset             => reset,
			enable            => enable,
			CoreValidIn       => CoreValidIn,
			CoreLoadStore     => CoreLoadStore,
			CoreAddrIn        => CoreAddrIn,
			CoreDataIn        => CoreDataIn,
			CoreValidOut      => CoreValidOut,
			CoreAck           => CoreAck,
			CoreDataOut       => CoreDataOut,
			DirectoryValidIn  => DirectoryValidIn,
			DirectoryValidOut => DirectoryValidOut,
			CacheDataIn       => CacheDataIn,
			CacheHit          => CacheHit,
			CacheOp           => CacheOp,
			CacheAddr         => CacheAddr,
			CacheDataOut      => CacheDataOut
		);

	-- Instantiate the Unit Under Test (UUT)
	uut_cache : cache_memory
		generic map(
			DATA_WIDTH  => DATA_WIDTH,
			BLOCK_WIDTH => BLOCK_WIDTH,
			CACHE_WIDTH => CACHE_WIDTH
		)
		port map(
			clk   => clk,
			reset => reset,
			addr  => addr,
			op    => op,
			data  => data,
			hit   => CacheHit,
			q     => CacheDataIn
		);

	-- Clock process definitions
	clk_process : process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process;

	data <= data_temp when enable = '0' else CacheDataOut;
	addr <= addr_temp when enable = '0' else CacheAddr;
	op   <= op_temp when enable = '0' else CacheOp;

	-- Stimulus process
	stim_proc : process
	begin
		-- hold reset state for 100 ns.
		reset <= '1';
		
		wait for clk_period * 10;
		reset <= '0';
		op_temp   <= "01";
		addr_temp <= x"002A";
		data_temp <= x"01";
		
		wait for clk_period;
		addr_temp <= x"0051";
		data_temp <= x"02";
		
		wait for clk_period;
		addr_temp <= x"0032";
		data_temp <= x"03";
		
		wait for clk_period; 
		addr_temp <= x"0117";
		data_temp <= x"04";
		
		wait for clk_period;
		addr_temp <= x"0998";
		data_temp <= x"05";
		
		wait for clk_period;
		op_temp <= "11";

		wait for 100 ns;
		reset <= '0';
		enable <= '1';
		CoreValidIn <= '1';
		CoreLoadStore <= '0';
		CoreAddrIn <= x"002A";
		
		wait for clk_period;
		CoreValidIn <= '0';
		
		wait for clk_period * 10;
		CoreValidIn <= '1';
		CoreLoadStore <= '0';
		CoreAddrIn <= x"004A";
		
		wait for clk_period;
		CoreValidIn <= '0';
		
		wait for clk_period * 10;
		CoreValidIn <= '1';
		CoreLoadStore <= '1';
		CoreAddrIn <= x"004A";
		CoreDataIn <= x"22";
		
		wait for clk_period;
		CoreValidIn <= '0';
		CoreLoadStore <= '0';
		

		wait;

	end process;

END;