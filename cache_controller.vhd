library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.logpack.all;

entity cache_controller is
	Generic(
		DIRECTORIES_N  : natural := 4;  -- Directories number
		DATA_WIDTH     : natural := 32; -- Data width
		BLOCK_WIDTH    : natural := 16; -- Memory address width
		CACHE_WIDTH    : natural := 4;
		--ROUTER_MEX_WIDTH : natural := 12;
		FIFO_REQ_WIDTH : natural := 8   -- Internal FIFO length. If the controller is busy, concurrent request are stored in the Request FIFO
	);
	Port(
		clk               : in  std_logic;
		reset             : in  std_logic;
		enable            : in  std_logic;

		-- Core interface
		CoreValidIn       : in  std_logic; -- Core valid signal, high if there is a valid request from the core
		CoreLoadStore     : in  std_logic; -- Core load or strore operation select
		CoreAddrIn        : in  std_logic_vector(BLOCK_WIDTH - 1 downto 0); -- Block address request from the core (load and store) 
		CoreDataIn        : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of store)
		CoreValidOut      : out std_logic; -- Core valid out, if high there is a valid response for the core 
		CoreAck           : out std_logic; -- Response for the core
		CoreDataOut       : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Data from the core (in case of load)

		-- Directory Interface
		DirectoryValidIn  : in  std_logic;
		DirectoryAddrIn   : in  std_logic_vector(BLOCK_WIDTH downto 0);
		DirectoryDataIn   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		DirectoryValidOut : out std_logic;
		DirectoryAddrOut  : out std_logic_vector(BLOCK_WIDTH downto 0);
		DirectoryDataOut  : out std_logic_vector(DATA_WIDTH - 1 downto 0);

		-- Cache interface
		CacheDataIn       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		CacheHit          : in  std_logic;
		CacheOp           : out std_logic_vector(1 downto 0);
		CacheAddr         : out std_logic_vector(BLOCK_WIDTH - 1 downto 0);
		CacheDataOut      : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end entity cache_controller;

architecture RTL of cache_controller is
	constant STATE_BIT_WIDTH   : natural := 2;
	constant OWNER_WIDTH       : natural := f_log2(DIRECTORIES_N);
	constant SHARER_LIST_WIDTH : natural := DIRECTORIES_N;
	constant DIRECTORY_WIDTH   : natural := STATE_BIT_WIDTH + OWNER_WIDTH + SHARER_LIST_WIDTH;

	-- Core/Controller message constants
	constant LOAD_REQUEST  : std_logic := '0';
	constant STORE_REQUEST : std_logic := '1';

	-- Controller/Cache memory constants
	constant LOAD_CACHE    : std_logic_vector(1 downto 0) := "00";
	constant STORE_CACHE   : std_logic_vector(1 downto 0) := "01";
	constant INVALID_CACHE : std_logic_vector(1 downto 0) := "10";

	-- MESI State value constant 
	constant INVALID_STATE   : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "00";
	constant MODIFIED_STATE  : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "01";
	constant SHARED_STATE    : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "10";
	constant EXCLUSIVE_STATE : std_logic_vector(STATE_BIT_WIDTH - 1 downto 0) := "11";

	-- FSM and temporany signals 
	type state_type is (idle, wait_hit, check_hit, get_block, up_date_directory);
	signal current_s           : state_type                                 := idle;
	signal core_data_temp      : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal core_valid_out_temp : std_logic                                  := '0';
	signal cache_write_en_temp : std_logic                                  := '0';
	signal core_ack_temp       : std_logic                                  := '0';
	signal core_addr_out_temp  : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');
	signal core_data_out_temp  : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal cache_data_out_temp : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
	signal cache_op_temp       : std_logic_vector(1 downto 0)               := (others => '0');
	signal cache_addr_temp     : std_logic_vector(BLOCK_WIDTH - 1 downto 0) := (others => '0');

begin
	CoreValidOut <= core_valid_out_temp;
	CoreDataOut  <= core_data_out_temp;
	CoreAck      <= core_ack_temp;

	CacheDataOut <= cache_data_out_temp;
	CacheOp      <= cache_op_temp;
	CacheAddr    <= cache_addr_temp;

	CU_process : process(clk, reset, enable)
	begin
		if reset = '1' then
			current_s <= idle;

		elsif rising_edge(clk) and enable = '1' then
			core_valid_out_temp <= '0';
			core_addr_out_temp  <= (others => '0');
			cache_write_en_temp <= '0';
			core_ack_temp       <= '0';
			cache_op_temp       <= "11";

			case current_s is
				when idle =>
					if CoreValidIn = '1' then -- If the core has a request for the Cache Controller
						cache_addr_temp <= CoreAddrIn;
						core_data_temp  <= CoreDataIn;
						if CoreLoadStore = LOAD_REQUEST then -- LOAD REQUEST
							cache_op_temp <= LOAD_CACHE;
							current_s     <= wait_hit;
						else            -- STORE REQUEST
							cache_op_temp       <= STORE_CACHE;
							cache_data_out_temp <= CoreDataIn;
							current_s           <= up_date_directory;
						-- The cache controller must update the directory and wait its response
						end if;
					else
						current_s <= idle;
					end if;

				when wait_hit =>
					current_s <= check_hit;

				when check_hit =>       -- Check if there is a cache hit				
					if CacheHit = '1' then -- A cache hit occurs, the controller passes the loaded data to the core
						core_valid_out_temp <= '1';
						core_ack_temp       <= '1';
						core_data_out_temp  <= CacheDataIn;
						current_s           <= idle;
					else
						-- Cache controller must request the memory block to the directory
						current_s <= get_block;
					end if;

				when get_block =>
					-- The block isn't in cache. The cache controller sends a request to the directory
					current_s <= idle;

				when up_date_directory =>
					-- The stored block must be update to its home directory
					current_s <= idle;
			end case;

		end if;
	end process;

end architecture RTL;
