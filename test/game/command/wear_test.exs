defmodule Game.Command.WearTest do
  use Data.ModelCase
  doctest Game.Command.Wear

  alias Data.Save
  alias Game.Command
  alias Game.Command.Wear

  @socket Test.Networking.Socket

  setup do
    start_and_clear_items()
    insert_item(%{id: 1, name: "Leather Chest", keywords: ["chest"], type: "armor", stats: %{slot: :chest}})
    insert_item(%{id: 2, name: "Mail Chest", keywords: [], type: "armor", stats: %{slot: :chest}})
    insert_item(%{id: 3, name: "Axe", keywords: [], type: "weapon"})

    @socket.clear_messages
    {:ok, %{session: :session, socket: :socket}}
  end

  describe "wearing" do
    test "wearing armor", %{session: session, socket: socket} do
      instance = item_instance(1)
      save = %Save{items: [instance], wearing: %{}}
      {:update, state} = Command.Wear.run({:wear, "chest"}, session, %{socket: socket, save: save})

      assert state.save.wearing == %{chest: instance}
      assert state.save.items == []

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(You are now wearing Leather Chest), look)
    end

    test "wearing armor replaces the old set", %{session: session, socket: socket} do
      leather_chest = item_instance(1)
      mail_chest = item_instance(2)

      save = %Save{items: [leather_chest], wearing: %{chest: mail_chest}}
      {:update, state} = Command.Wear.run({:wear, "chest"}, session, %{socket: socket, save: save})

      assert state.save.wearing == %{chest: leather_chest}
      assert state.save.items == [mail_chest]

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(You are now wearing Leather Chest), look)
    end

    test "wearing only armor", %{session: session, socket: socket} do
      save = %Save{items: [item_instance(1), item_instance(3)]}
      :ok = Command.Wear.run({:wear, "axe"}, session, %{socket: socket, save: save})

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(You cannot wear Axe), look)
    end

    test "item not found", %{session: session, socket: socket} do
      save = %Save{items: [item_instance(1)]}
      :ok = Command.Wear.run({:wear, "bracer"}, session, %{socket: socket, save: save})

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r("bracer" could not be found), look)
    end
  end

  describe "remove" do
    test "removing armor", %{session: session, socket: socket} do
      leather_chest = item_instance(1)

      save = %Save{items: [], wearing: %{chest: leather_chest}}
      {:update, state} = Command.Wear.run({:remove, "chest"}, session, %{socket: socket, save: save})

      assert state.save.wearing == %{}
      assert state.save.items == [leather_chest]

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(You removed Leather Chest from your chest), look)
    end

    test "does not fail when removing a slot that is empty", %{session: session, socket: socket} do
      save = %Save{items: [item_instance(1)], wearing: %{}}
      :ok = Command.Wear.run({:remove, "chest"}, session, %{socket: socket, save: save})

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(Nothing was on your chest.), look)
    end

    test "unknown slot", %{session: session, socket: socket} do
      save = %Save{items: [item_instance(1)], wearing: %{}}
      :ok = Command.Wear.run({:remove, "finger"}, session, %{socket: socket, save: save})

      [{^socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(Unknown armor slot), look)
    end
  end

  describe "removing from wearing map" do
    test "removes from wearing and adds to item list" do
      chest_piece = item_instance(1)
      other_item = item_instance(2)

      assert {%{}, [^chest_piece, ^other_item]} = Wear.remove(:chest, %{chest: chest_piece}, [other_item])
    end
  end
end
